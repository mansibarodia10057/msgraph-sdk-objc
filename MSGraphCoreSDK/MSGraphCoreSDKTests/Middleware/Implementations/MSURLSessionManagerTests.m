//
//  MSURLSessionManagerTests.m
// Copyright (c) Microsoft Corporation.  All Rights Reserved.  Licensed under the MIT License.  See License in the project root for license information.
//

#import <XCTest/XCTest.h>
#import "MSGraphCoreSDK.h"
#import "MSURLSessionTaskDelegate.h"
#import "OCMock.h"
#import "MSGraphCoreSDKTests.h"


@interface MSURLSessionManager()
@property (strong, nonatomic) NSURLSessionConfiguration *urlSessionConfiguration;
@property (strong, nonatomic) NSURLSession *urlSession;
@property (strong, nonatomic) NSMutableDictionary *taskDelegates;
@property (nonatomic, strong) id<MSGraphMiddleware> nextMiddleware;
@end

@interface MSURLSessionTaskDelegate()
@property (strong, nonatomic) NSProgress *progress;
@property (strong, nonatomic) NSMutableData *mutableData;
@property (strong, nonatomic) NSURL *downloadPath;
@property (strong, nonatomic) MSURLSessionTaskCompletion completion;
@end

@interface MSURLSessionManagerTests : MSGraphCoreSDKTests
@property (nonatomic,retain) MSURLSessionManager * sessionManager;

@property (nonatomic,retain) id<MSHttpProvider> httpProviderDelegate;

@property (nonatomic,retain) NSURL * requestURL;
@property (nonatomic,retain) NSURLRequest *request;
@property (nonatomic) __block BOOL bCompletionBlockInvoked;
@end

@implementation MSURLSessionManagerTests

- (void)setUp {
    [super setUp];
    self.requestURL = [NSURL URLWithString:MSGraphBaseURL];
    self.request = [[NSURLRequest alloc] initWithURL:_requestURL];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.sessionManager = [[MSURLSessionManager alloc] initWithSessionConfiguration:config];

    self.httpProviderDelegate = _sessionManager;
    self.bCompletionBlockInvoked = NO;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.requestURL = nil;
    self.request = nil;
    self.sessionManager = nil;

    [super tearDown];

}

- (void)testMSURLSessionManagerInitWithNilconfig{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    MSURLSessionManager * initSessionManager = [[MSURLSessionManager alloc] initWithSessionConfiguration:nil];
    XCTAssertNotNil(initSessionManager);
    XCTAssertEqualObjects(initSessionManager.urlSession.configuration, config);
    XCTAssertEqualObjects(initSessionManager.urlSession.delegate, initSessionManager);
}
- (void)testMSURLSessionManagerInit{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    MSURLSessionManager * initSessionManager = [[MSURLSessionManager alloc] initWithSessionConfiguration:config];
    XCTAssertNotNil(initSessionManager);
    XCTAssertNotNil(initSessionManager.urlSessionConfiguration);
    XCTAssertEqualObjects(initSessionManager.urlSessionConfiguration, config);

    XCTAssertNotNil(initSessionManager.urlSessionConfiguration);
    XCTAssertEqualObjects(initSessionManager.urlSession.configuration, config);
    XCTAssertEqualObjects(initSessionManager.urlSession.delegate, initSessionManager);
}

#pragma mark - dataTaskWithRequest success
-(void)testMSURLSessionManagerInitAndMSHttpProviderDelegateDataTaskWithRequestWithOk{

    //Creating a demo response dictionary and data
    NSDictionary *returnDic = @{@"testkey":@"testvalue"};
    NSData *returnData = [NSJSONSerialization dataWithJSONObject:returnDic options:0 error:nil];

    id<NSURLSessionDataDelegate> nsURLSessionDataDelegate = _sessionManager;

    __weak typeof(self) weakSelf = self;

    MSDataCompletionHandler msdataCompletion =^(NSData *data, NSURLResponse *response, NSError *error) {
        weakSelf.bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertNotNil(data);
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        XCTAssertNotNil(dict);
        XCTAssertTrue([dict isEqualToDictionary:returnDic]);
    };

    //Creating data task
    NSURLSessionDataTask *datatask = [_httpProviderDelegate dataTaskWithRequest:_request completionHandler:msdataCompletion];
    XCTAssertNotNil(datatask);

    //Creating task delegate
    MSURLSessionTaskDelegate * msUrlsessionTaskDelegate = [_sessionManager.taskDelegates objectForKey:@(datatask.taskIdentifier)];
    XCTAssertNotNil(msUrlsessionTaskDelegate);
    XCTAssertEqualObjects(msUrlsessionTaskDelegate.completion, msdataCompletion);

    //Mocking did receive data
    [nsURLSessionDataDelegate URLSession:_sessionManager.urlSession dataTask:datatask didReceiveData:returnData];

    [self mockMSURLSessionTaskDelegateDidCompleteWithError:msUrlsessionTaskDelegate task:datatask statusCode:MSExpectedResponseCodesOK bpath:NO];
    //Mocking did complete
    [nsURLSessionDataDelegate URLSession:_sessionManager.urlSession task:datatask didCompleteWithError:nil];
    XCTAssertTrue(_bCompletionBlockInvoked,@"MSDataCompletionHandler was not invoked");
}

#pragma mark - downloadTaskWithRequest success
-(void)testMSHttpProviderDelegateDownloadTaskWithRequestWithOk{
    NSURL *returnLocation = [NSURL URLWithString:@"file://test/foo"];
    MSRawDownloadCompletionHandler downloadCompletion = ^(NSURL *location, NSURLResponse *response, NSError *error){
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertEqualObjects(location, returnLocation);
    };

    id<NSURLSessionDownloadDelegate> nsURLSessionDownloadDelegate = _sessionManager;

    NSProgress *progress = [NSProgress new];
    NSURLSessionDownloadTask *downloadtask = [_httpProviderDelegate downloadTaskWithRequest:_request progress:&progress completionHandler:downloadCompletion];
    XCTAssertNotNil(downloadtask);
    MSURLSessionTaskDelegate * msUrlsessionTaskDelegate = [_sessionManager.taskDelegates objectForKey:@(downloadtask.taskIdentifier)];
    XCTAssertNotNil(msUrlsessionTaskDelegate);
    XCTAssertEqualObjects(msUrlsessionTaskDelegate.completion, downloadCompletion);
    [nsURLSessionDownloadDelegate URLSession:_sessionManager.urlSession downloadTask:downloadtask didWriteData:240 totalBytesWritten:240 totalBytesExpectedToWrite:720];

    [nsURLSessionDownloadDelegate URLSession:_sessionManager.urlSession downloadTask:downloadtask didWriteData:240 totalBytesWritten:480 totalBytesExpectedToWrite:720];

    [nsURLSessionDownloadDelegate URLSession:_sessionManager.urlSession downloadTask:downloadtask didWriteData:240 totalBytesWritten:720 totalBytesExpectedToWrite:720];

    XCTAssertEqual(progress.fractionCompleted,1.0);

    [self mockMSURLSessionTaskDelegateDidCompleteWithError:msUrlsessionTaskDelegate task:downloadtask statusCode:MSExpectedResponseCodesOK bpath:YES];

    [nsURLSessionDownloadDelegate URLSession:_sessionManager.urlSession downloadTask:downloadtask didFinishDownloadingToURL:returnLocation];

    XCTAssertTrue(_bCompletionBlockInvoked,@"MSRawDownloadCompletionHandler was not invoked");
}

#pragma mark - UploadTaskWithRequestFrom Data success
-(void)testMSHttpProviderDelegateUploadTaskFromDataWithRequest{
    MSRawUploadCompletionHandler uploadCompletion = ^(NSData *data, NSURLResponse *response, NSError *error) {
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertNil(data);
    };

    NSDictionary *uploadDic = @{@"testkey":@"testvalue"};
    NSData *uploadData = [NSJSONSerialization dataWithJSONObject:uploadDic options:0 error:nil];

    NSProgress *progress = [NSProgress new];

    NSURLSessionUploadTask * uploadtask = [_httpProviderDelegate uploadTaskWithRequest:_request fromData:uploadData progress:&progress completionHandler:uploadCompletion];
    XCTAssertNotNil(uploadtask);
    MSURLSessionTaskDelegate * msUrlsessionTaskDelegate = [_sessionManager.taskDelegates objectForKey:@(uploadtask.taskIdentifier)];
    XCTAssertNotNil(msUrlsessionTaskDelegate);
    XCTAssertEqualObjects(msUrlsessionTaskDelegate.completion, uploadCompletion);
    id<NSURLSessionTaskDelegate> nsURLSessionTaskDelegate = _sessionManager;

    [nsURLSessionTaskDelegate URLSession:_sessionManager.urlSession task:uploadtask didSendBodyData:240 totalBytesSent:240 totalBytesExpectedToSend:720];

    [nsURLSessionTaskDelegate URLSession:_sessionManager.urlSession task:uploadtask didSendBodyData:240 totalBytesSent:480 totalBytesExpectedToSend:720];

    [nsURLSessionTaskDelegate URLSession:_sessionManager.urlSession task:uploadtask didSendBodyData:240 totalBytesSent:720 totalBytesExpectedToSend:720];

    XCTAssertEqual(progress.fractionCompleted,1.0);

    [self mockMSURLSessionTaskDelegateDidCompleteWithError:msUrlsessionTaskDelegate task:uploadtask statusCode:MSExpectedResponseCodesOK bpath:NO];

    [nsURLSessionTaskDelegate URLSession:_sessionManager.urlSession task:uploadtask didCompleteWithError:nil];
    XCTAssertTrue(_bCompletionBlockInvoked,@"MSRawUploadCompletionHandler was not invoked");
}
#pragma mark - UploadTaskWithRequestFrom File success
-(void)testMSHttpProviderDelegateUploadTaskFromFileWithRequest{
    MSRawUploadCompletionHandler uploadCompletion = ^(NSData *data, NSURLResponse *response, NSError *error) {
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertNil(data);
    };

    NSURL *uploadFileURL = [NSURL URLWithString:@"file://test/foo"];
    NSURLSessionUploadTask * uploadtask = [_httpProviderDelegate uploadTaskWithRequest:_request fromFile:uploadFileURL progress:nil completionHandler:uploadCompletion];
    XCTAssertNotNil(uploadtask);
    MSURLSessionTaskDelegate * msUrlsessionTaskDelegate = [_sessionManager.taskDelegates objectForKey:@(uploadtask.taskIdentifier)];
    XCTAssertNotNil(msUrlsessionTaskDelegate);
    XCTAssertEqualObjects(msUrlsessionTaskDelegate.completion, uploadCompletion);

    [self mockMSURLSessionTaskDelegateDidCompleteWithError:msUrlsessionTaskDelegate task:uploadtask statusCode:MSExpectedResponseCodesOK bpath:NO];
    id<NSURLSessionTaskDelegate> nsURLSessionTaskDelegate = _sessionManager;
    [nsURLSessionTaskDelegate URLSession:_sessionManager.urlSession task:uploadtask didCompleteWithError:nil];
    XCTAssertTrue(_bCompletionBlockInvoked);
}

#pragma mark - Test set next

- (void)testSetNext{
    id<MSGraphMiddleware> tempMiddleware = OCMProtocolMock(@protocol(MSGraphMiddleware));
    [_sessionManager setNext:tempMiddleware];
    XCTAssertEqualObjects(tempMiddleware, _sessionManager.nextMiddleware);
    id<MSGraphMiddleware> tempMiddleware1 = OCMProtocolMock(@protocol(MSGraphMiddleware));
    [_sessionManager setNext:tempMiddleware1];
    XCTAssertEqualObjects(_sessionManager.nextMiddleware, tempMiddleware1);
}

#pragma mark - Middleware execution
-(void)testMSHTTPProviderForMiddlewareExecutionWithDataTask{

    MSDataCompletionHandler dataCompletion = ^(NSData *data, NSURLResponse *response, NSError *error){
    };
    MSURLSessionDataTask *dataTask = [[MSURLSessionDataTask alloc] initWithRequest:[_request mutableCopy] client:self.mockClient completion:dataCompletion];

    HTTPRequestCompletionHandler requestCompletion = ^(id data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertNotNil(data);
    };

    id mockNSTask = OCMClassMock([NSURLSessionDataTask class]);



    id mockMSURLSessionManager = OCMPartialMock(_sessionManager);

    OCMStub([mockMSURLSessionManager dataTaskWithRequest:[OCMArg any] completionHandler:[OCMArg any]]).andReturn(mockNSTask).andDo(^(NSInvocation *invocation){
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:MSGraphBaseURL] statusCode:MSExpectedResponseCodesOK HTTPVersion:@"foo" headerFields:nil];
        MSDataCompletionHandler completionHandler;
        [invocation getArgument:&completionHandler atIndex:3];
        completionHandler([NSData new],response,nil);
    });
    OCMStub([mockNSTask resume])
    .andDo(^(NSInvocation *invocation){
    });

    [_sessionManager execute:dataTask withCompletionHandler:requestCompletion];
    [mockNSTask stopMocking];
     XCTAssertTrue(_bCompletionBlockInvoked);
}

-(void)testMSHTTPProviderForMiddlewareExecutionWithDownloadTask{

    MSDownloadCompletionHandler downloadCompletion = ^(NSURL *fileUrl, NSURLResponse *response, NSError *error){
    };
    MSURLSessionDownloadTask *downloadTask = [[MSURLSessionDownloadTask alloc] initWithRequest:[_request mutableCopy] client:self.mockClient completionHandler:downloadCompletion];

    HTTPRequestCompletionHandler requestCompletion = ^(id data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertNotNil(data);
    };

    id mockNSTask = OCMClassMock([NSURLSessionDownloadTask class]);



    id mockMSURLSessionManager = OCMPartialMock(_sessionManager);
    OCMStub([mockMSURLSessionManager downloadTaskWithRequest:[OCMArg any] progress:[OCMArg anyObjectRef] completionHandler:[OCMArg any]]).andReturn(mockNSTask).andDo(^(NSInvocation *invocation){
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:MSGraphBaseURL] statusCode:MSExpectedResponseCodesOK HTTPVersion:@"foo" headerFields:nil];
        MSDownloadCompletionHandler completionHandler;
        [invocation getArgument:&completionHandler atIndex:4];
        completionHandler([NSURL URLWithString:@"https://foo"],response,nil);
    });
    OCMStub([mockNSTask resume])
    .andDo(^(NSInvocation *invocation){

    });

    [_sessionManager execute:downloadTask withCompletionHandler:requestCompletion];
    [mockNSTask stopMocking];
    XCTAssertTrue(_bCompletionBlockInvoked);
}

-(void)testMSHTTPProviderForMiddlewareExecutionWithUploadTaskFromData{

    MSUploadCompletionHandler dataCompletion = ^(NSData *data, NSURLResponse *response, NSError *error){
    };
    MSURLSessionUploadTask *dataTask = [[MSURLSessionUploadTask alloc] initWithRequest:[_request mutableCopy]  data:[NSData new] client:self.mockClient completionHandler:dataCompletion];

    HTTPRequestCompletionHandler requestCompletion = ^(id data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertNotNil(data);
    };

    id mockNSTask = OCMClassMock([NSURLSessionUploadTask class]);



    id mockMSURLSessionManager = OCMPartialMock(_sessionManager);

    OCMStub([mockMSURLSessionManager uploadTaskWithRequest:[OCMArg any] fromData:[OCMArg any] progress:[OCMArg anyObjectRef] completionHandler:[OCMArg any]]).andReturn(mockNSTask).andDo(^(NSInvocation *invocation){
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:MSGraphBaseURL] statusCode:MSExpectedResponseCodesOK HTTPVersion:@"foo" headerFields:nil];
        MSUploadCompletionHandler completionHandler;
        [invocation getArgument:&completionHandler atIndex:5];
        completionHandler([NSData new],response,nil);
    });
    OCMStub([mockNSTask resume])
    .andDo(^(NSInvocation *invocation){
    });

    [_sessionManager execute:dataTask withCompletionHandler:requestCompletion];
    [mockNSTask stopMocking];

    XCTAssertTrue(_bCompletionBlockInvoked);
}

-(void)testMSHTTPProviderForMiddlewareExecutionWithUploadTaskFromFile{

    MSUploadCompletionHandler dataCompletion = ^(NSData *data, NSURLResponse *response, NSError *error){
    };
    MSURLSessionUploadTask *dataTask = [[MSURLSessionUploadTask alloc] initWithRequest:[_request mutableCopy]  fromFile:[NSURL URLWithString:MSGraphBaseURL] client:self.mockClient completionHandler:dataCompletion];

    HTTPRequestCompletionHandler requestCompletion = ^(id data, NSURLResponse * _Nullable response, NSError * _Nullable error){
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, MSExpectedResponseCodesOK);
        XCTAssertNotNil(data);
    };

    id mockNSTask = OCMClassMock([NSURLSessionUploadTask class]);



    id mockMSURLSessionManager = OCMPartialMock(_sessionManager);

    OCMStub([mockMSURLSessionManager uploadTaskWithRequest:[OCMArg any] fromFile:[OCMArg any] progress:[OCMArg anyObjectRef] completionHandler:[OCMArg any]]).andReturn(mockNSTask).andDo(^(NSInvocation *invocation){
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:MSGraphBaseURL] statusCode:MSExpectedResponseCodesOK HTTPVersion:@"foo" headerFields:nil];
        MSUploadCompletionHandler completionHandler;
        [invocation getArgument:&completionHandler atIndex:5];
        completionHandler([NSData new],response,nil);
    });
    OCMStub([mockNSTask resume])
    .andDo(^(NSInvocation *invocation){
    });

    [_sessionManager execute:dataTask withCompletionHandler:requestCompletion];
    [mockNSTask stopMocking];

    XCTAssertTrue(_bCompletionBlockInvoked);
}

#pragma mark - Mock HTTP URL Response
-(void)mockMSURLSessionTaskDelegateDidCompleteWithError:(MSURLSessionTaskDelegate *)msUrlsessionTaskDelegate task:(NSURLSessionTask *)task statusCode:(NSInteger)statusCode bpath:(BOOL)bpath{
    MSURLSessionTaskDelegate *mockMSURLSessionTaskDelegate = OCMPartialMock(msUrlsessionTaskDelegate);

    OCMStub([mockMSURLSessionTaskDelegate task:task didCompleteWithError:[OCMArg any]])
    .andDo(^(NSInvocation *invocation){
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self->_requestURL statusCode:statusCode HTTPVersion:@"foo" headerFields:nil];
        if(bpath){
            mockMSURLSessionTaskDelegate.completion(mockMSURLSessionTaskDelegate.downloadPath, response, nil);
        }
        else{
            mockMSURLSessionTaskDelegate.completion(mockMSURLSessionTaskDelegate.mutableData, response, nil);
        }
      }
    );
}

@end

