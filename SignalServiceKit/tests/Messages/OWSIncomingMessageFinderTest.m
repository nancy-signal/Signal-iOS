//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSIncomingMessageFinder.h"
#import "OWSDevice.h"
#import "OWSPrimaryStorage.h"
#import "TSContactThread.h"
#import "TSIncomingMessage.h"
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSIncomingMessageFinder (Testing)

- (void)registerExtension;

@end

@interface OWSIncomingMessageFinderTest : XCTestCase

@property (nonatomic) NSString *sourceId;
@property (nonatomic) TSThread *thread;
@property (nonatomic) OWSIncomingMessageFinder *finder;
@property (nonatomic) YapDatabaseConnection *dbConnection;

@end

@implementation OWSIncomingMessageFinderTest

- (void)setUp
{
    [super setUp];
    self.sourceId = @"some-source-id";
    self.thread = [TSContactThread getOrCreateThreadWithContactId:self.sourceId];
    self.finder = [OWSIncomingMessageFinder new];
    [self.finder registerExtension];
    self.dbConnection = [OWSPrimaryStorage sharedManager].dbReadConnection;
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)createIncomingMessageWithTimestamp:(uint64_t)timestamp
                                  authorId:(NSString *)authorId
                            sourceDeviceId:(uint32_t)sourceDeviceId
{
    TSIncomingMessage *incomingMessage = [[TSIncomingMessage alloc] initIncomingMessageWithTimestamp:timestamp
                                                                                            inThread:self.thread
                                                                                            authorId:authorId
                                                                                      sourceDeviceId:sourceDeviceId
                                                                                         messageBody:@"foo"
                                                                                       attachmentIds:@[]
                                                                                    expiresInSeconds:0
                                                                                       quotedMessage:nil
                                                                                        contactShare:nil];
    [incomingMessage save];
}

- (void)testExistingMessages
{

    uint64_t timestamp = 1234;
    __block BOOL result;

    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        result = [self.finder existsMessageWithTimestamp:timestamp
                                                sourceId:self.sourceId
                                          sourceDeviceId:OWSDevicePrimaryDeviceId
                                             transaction:transaction];
    }];


    // Sanity check.
    XCTAssertFalse(result);

    // Different timestamp
    [self createIncomingMessageWithTimestamp:timestamp + 1
                                    authorId:self.sourceId
                              sourceDeviceId:OWSDevicePrimaryDeviceId];

    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        result = [self.finder existsMessageWithTimestamp:timestamp
                                                sourceId:self.sourceId
                                          sourceDeviceId:OWSDevicePrimaryDeviceId
                                             transaction:transaction];
    }];

    XCTAssertFalse(result);

    // Different authorId
    [self createIncomingMessageWithTimestamp:timestamp
                                    authorId:@"some-other-author-id"
                              sourceDeviceId:OWSDevicePrimaryDeviceId];

    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        result = [self.finder existsMessageWithTimestamp:timestamp
                                                sourceId:self.sourceId
                                          sourceDeviceId:OWSDevicePrimaryDeviceId
                                             transaction:transaction];
    }];
    XCTAssertFalse(result);

    // Different device
    [self createIncomingMessageWithTimestamp:timestamp
                                    authorId:self.sourceId
                              sourceDeviceId:OWSDevicePrimaryDeviceId + 1];

    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        result = [self.finder existsMessageWithTimestamp:timestamp
                                                sourceId:self.sourceId
                                          sourceDeviceId:OWSDevicePrimaryDeviceId
                                             transaction:transaction];
    }];
    XCTAssertFalse(result);

    // The real deal...
    [self createIncomingMessageWithTimestamp:timestamp authorId:self.sourceId sourceDeviceId:OWSDevicePrimaryDeviceId];

    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        result = [self.finder existsMessageWithTimestamp:timestamp
                                                sourceId:self.sourceId
                                          sourceDeviceId:OWSDevicePrimaryDeviceId
                                             transaction:transaction];
    }];

    XCTAssertTrue(result);
}

@end

NS_ASSUME_NONNULL_END
