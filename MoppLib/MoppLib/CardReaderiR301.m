//
//  CardReaderIR301.m
//  MoppLib
//
/*
 * Copyright 2017 - 2023 Riigi Infosüsteemi Amet
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#import "CardReaderiR301.h"
#import <Foundation/Foundation.h>
#import "ReaderInterface.h"
#import "winscard.h"
#import "ft301u.h"
#import "wintypes.h"
#import "NSString+Additions.h"
#import "NSData+Additions.h"
#import "MoppLibCardReaderManager.h"
#import "MoppLibError.h"
#import "MoppLibPrivateConstants.h"
#import "CardActionsManager.h"
#import <Dispatch/Dispatch.h>

@interface CardReaderiR301() <ReaderInterfaceDelegate>
@property (nonatomic, strong) DataSuccessBlock successBlock;
@property (nonatomic, strong) FailureBlock failureBlock;
@property (nonatomic, strong) ReaderInterface *interface;
@property (nonatomic) SCARDHANDLE contextHandle;
@property (nonatomic) MoppLibCardChipType chipType;
@end

@implementation CardReaderiR301

- (MoppLibCardChipType)cardChipType {
    return _chipType;
}

-(void)updateContextHandle:(SCARDCONTEXT) contextHandle {
    _contextHandle = contextHandle;
}

- (void)setContextHandle:(SCARDHANDLE)contextHandle {
    printLog(@"%d", contextHandle);
    _contextHandle = contextHandle;
}

-(id)initWithInterface:(ReaderInterface*)interface andContextHandle:(SCARDHANDLE)contextHandle
{
    if (self = [super init]) {
        _interface = interface;
        _contextHandle = contextHandle;
        return self;
    }
    return nil;
}

-(void)setupWithSuccess:(DataSuccessBlock)success failure:(FailureBlock)failure {
    _successBlock = success;
    _failureBlock = failure;
}

#pragma mark - CardReaderWrapper

- (void)transmitCommand:(const NSString *)commandHex success:(DataSuccessBlock)success failure:(FailureBlock)failure {
    _successBlock = success;
    _failureBlock = failure;

    printLog(@"ID-CARD: CardReaderiR301. transmitCommand. Resetting reader restart and stopping card status polling");
    [[MoppLibCardReaderManager sharedInstance] resetReaderRestart];
    [[MoppLibCardReaderManager sharedInstance] stopPollingCardStatus];

    NSData *apduData = [commandHex toHexData];
    [self recursiveTransmitAPDUData:apduData responseData:[NSMutableData data] completion:^(NSData *responseData, NSError *error) {
        if (error) {
            [self respondWithError:error];
        } else {
            [self respondWithSuccess:responseData];
        }
    }];
}

- (void)recursiveTransmitAPDUData:(NSData *)apduData responseData:(NSMutableData *)responseData completion:(void (^)(NSData *responseData, NSError *error))completion {
    [self transmitAPDUData:apduData completion:^(NSData *response, NSError *error) {
        if (error) {
            completion(nil, error);
        } else {
            unsigned char trailing0 = ((unsigned char *)[response bytes])[response.length - 2];
            unsigned char trailing1 = ((unsigned char *)[response bytes])[response.length - 1];

            BOOL needMoreData = trailing0 == 0x61;
            BOOL reissueCommand = trailing0 == 0x6C; // Reissue command if SW1 == 6C

            [responseData appendData:response];

            if (needMoreData || reissueCommand) {
                if (reissueCommand) {
                    NSData *newCommandData = [self reissuedCommandDataForLe:trailing1 originalData:apduData];
                    if (!newCommandData) {
                        completion(nil, nil); // Empty response data indicates error
                    } else {
                        [self recursiveTransmitAPDUData:newCommandData responseData:responseData completion:completion];
                    }
                } else {
                    // Need more data, send another APDU to get it
                    unsigned char getResponseApdu[5] = { 0x00, 0xC0, 0x00, 0x00, 0x00 };
                    getResponseApdu[4] = trailing1;

                    [self recursiveTransmitAPDUData:[NSData dataWithBytes:&getResponseApdu[0] length:sizeof(getResponseApdu)]
                                        responseData:responseData completion:completion];
                }
            } else {
                completion(responseData, nil);
            }
        }
    }];
}

- (void)transmitAPDUData:(NSData *)apduData completion:(void (^)(NSData *response, NSError *error))completion {
    SCARD_IO_REQUEST pioSendPci;
    unsigned char response[512];
    unsigned int responseSize = sizeof(response);
    unsigned char apdu[512];
    NSUInteger apduSize = [apduData length];

    [apduData getBytes:apdu length:apduSize];

    memset(&pioSendPci, 0, sizeof(SCARD_IO_REQUEST));
    pioSendPci.cbPciLength = sizeof(pioSendPci);
    pioSendPci.dwProtocol = SCARD_PROTOCOL_T1;

    printLog(@"Sending APDU: %@", [apduData hexString]);

    if (SCARD_S_SUCCESS == SCardTransmit(
        _contextHandle,
        &pioSendPci,
        &apdu[0], (DWORD)apduSize,
        NULL,
        &response[0], &responseSize)) {

        NSData *responseData = [NSData dataWithBytes:&response[0] length:responseSize];
        printLog(@"IR301 Response: %@", [responseData hexString]);
        completion(responseData, nil);
    } else {
        printLog(@"ID-CARD: Failed to send APDU data");
        NSError *error = [NSError errorWithDomain:@"MoppLib" code: -1 userInfo:nil];
        completion(nil, error);
    }
}

- (NSData *)reissuedCommandDataForLe:(unsigned char)le originalData:(NSData *)originalAPDUData {
    NSMutableData *apduData = [NSMutableData dataWithData:originalAPDUData];
    ((unsigned char *)[apduData mutableBytes])[apduData.length - 1] = le;
    return apduData;
}


- (void)powerOnCard:(DataSuccessBlock)success failure:(FailureBlock)failure  {
    self.successBlock = success;
    self.failureBlock = failure;

    LONG iRet = 0;
    DWORD dwActiveProtocol = -1;
    char mszReaders[128];
    DWORD dwReaders = -1;

    iRet = SCardListReaders(_contextHandle, NULL, mszReaders, &dwReaders);
    if(iRet != SCARD_S_SUCCESS) {
        printLog(@"SCardListReaders error %08x",iRet);
        failure(nil);
        return;
    }

    iRet = SCardConnect(_contextHandle,mszReaders,SCARD_SHARE_SHARED,SCARD_PROTOCOL_T0 | SCARD_PROTOCOL_T1,&_contextHandle,&dwActiveProtocol);
    if (iRet != SCARD_S_SUCCESS) {
        failure(nil);
        return;
    }

    char modelNameBuf[100];
    unsigned int modelNameLength = sizeof(modelNameBuf);
    FtGetAccessoryModelName(_contextHandle, &modelNameLength, modelNameBuf);
    modelNameBuf[modelNameLength] = '\0';
    NSString *modelName = [NSString  stringWithCString:modelNameBuf encoding:NSUTF8StringEncoding];

    if (![MoppLibCardReaderManager isCardReaderModelSupported:modelName]) {
        [NSNotificationCenter.defaultCenter postNotificationName:kMoppLibNotificationRevokeUnsupportedReader object:nil];
        printLog(@"ID-CARD: Unsupported reader: %@", modelName);
        [self respondWithError:[MoppLibError readerNotFoundError]];
        return;
    }

    DWORD atrBufSize = 32;
    BYTE atrBuf[32];
    DWORD dwStatus;
    iRet = SCardStatus(_contextHandle, NULL, NULL, &dwStatus, NULL, (LPBYTE)&atrBuf, &atrBufSize);
    printLog(@"%d", dwStatus);

    NSData *atr = [[NSData alloc] initWithBytes:atrBuf length:atrBufSize];
    _chipType = [MoppLibCardReaderManager atrToChipType:atr];

    if (dwStatus == SCARD_PRESENT) {
        [PrivateConstants setIDCardRestartedValue:FALSE];
        success(nil);
    } else {
        printLog(@"ID-CARD: Did not successfully power on card");
        if (![PrivateConstants getIDCardRestartedValue]) {
            if (@available(iOS 14, *)) {
                [[MoppLibCardReaderManager sharedInstance] restartDiscoveringReaders:2.0f];
            } else {
                [self powerOnIdCard:^(NSData *responseData) {
                    [PrivateConstants setIDCardRestartedValue:FALSE];
                    success(nil);
                } failure:^(NSError *error) {
                    [[MoppLibCardReaderManager sharedInstance] restartDiscoveringReaders:2.0f];
                }];
            }
        } else {
            [self respondWithError:[MoppLibError readerProcessFailedError]];
            [PrivateConstants setIDCardRestartedValue:FALSE];
        }
    }
}

- (void)powerOnIdCard:(DataSuccessBlock)success failure:(FailureBlock)failure  {
    self.successBlock = success;
    self.failureBlock = failure;

    unsigned int length = 0;
    char buffer[20] = {0};
    LONG ret = FtGetReaderName(_contextHandle, &length, buffer);
    if (ret != SCARD_S_SUCCESS || length == 0) {
        printLog(@"ID-CARD: Unable to power on card");
        failure(false);
        return;
    }

    NSString* _name = [NSString stringWithUTF8String:buffer];

    DWORD atrBufSize = 32;
    BYTE atrBuf[32];
    DWORD dwStatus;
    LONG iRet = SCardStatus(self->_contextHandle, NULL, NULL, &dwStatus, NULL, (LPBYTE)&atrBuf, &atrBufSize);
    printLog(@"dwStatus %d", dwStatus);
    printLog(@"iRet %d", iRet);

    NSData *atr = [[NSData alloc] initWithBytes:atrBuf length:atrBufSize];
    _chipType = [MoppLibCardReaderManager atrToChipType:atr];

    if (dwStatus == SCARD_PRESENT) {
        dispatch_async(dispatch_get_main_queue(), ^{
            printLog(@"ID-CARD: Card name: %@", _name);
            success(nil);
        });
    } else {
        [[MoppLibCardReaderManager sharedInstance] restartDiscoveringReaders:2.0f];
    }
}

- (NSString *)getReaderList {
    DWORD readerLength = 0;
    LONG ret = SCardListReaders(_contextHandle, nil, nil, &readerLength);
    if(ret != 0) {
        printLog(@"ID-CARD: Unable to get reader list");
        return nil;
    }

    LPSTR readers = (LPSTR)malloc(readerLength * sizeof(LPSTR));
    ret = SCardListReaders(_contextHandle, nil, readers, &readerLength);
    if (ret != 0) {
        printLog(@"ID-CARD: Unable to get list of readers");
        free(readers);
        return nil;
    }

    NSString * strreaders = [NSString stringWithUTF8String:readers];
    free(readers);
    return strreaders;
}

- (void)respondWithError:(NSError *)error {
  @synchronized (self) {
    FailureBlock failure = self.failureBlock;
    self.failureBlock = nil;
    self.successBlock = nil;

    if (failure) {
      failure(error);
    }
  }
}

- (void)respondWithSuccess:(NSObject *)result {
  @synchronized (self) {
    DataSuccessBlock success = self.successBlock;
    self.failureBlock = nil;
    self.successBlock = nil;

    if (success) {
      success(result);
    }
  }
}

- (void)isCardInserted:(BoolBlock)completion {
    DWORD status = [self cardStatus];
    completion(status == SCARD_PRESENT || status == SCARD_POWERED || status == SCARD_SWALLOWED);
}

- (BOOL)isConnected {
    DWORD dwStatus;
    return SCardStatus(_contextHandle, NULL, NULL, &dwStatus, NULL, NULL, NULL) == SCARD_S_SUCCESS;
}

- (DWORD)cardStatus {
    DWORD status;
    LONG ret = 0;

    ret = SCardStatus(_contextHandle, NULL, NULL, &status, NULL, NULL, NULL);
    if (ret != SCARD_S_SUCCESS) {
        return SCARD_ABSENT;
    }

    return status;
}

- (void)isCardPoweredOn:(BoolBlock) completion {
    completion([self cardStatus] == SCARD_PRESENT);
}

- (void)resetReader {
}

- (void)cardInterfaceDidDetach:(BOOL)attached {

}

- (void) readerInterfaceDidChange:(BOOL)attached bluetoothID:(NSString *)bluetoothID {

}

- (void)didGetBattery:(NSInteger)battery {

}


- (void)findPeripheralReader:(NSString *)readerName {

}


@end
