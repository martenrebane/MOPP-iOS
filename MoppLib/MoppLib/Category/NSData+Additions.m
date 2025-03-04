//
//  NSData+Additions.m
//  MoppLib
//
/*
 * Copyright 2017 - 2024 Riigi Infosüsteemi Amet
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

#import "NSData+Additions.h"
#import "NSString+Additions.h"

@implementation NSData (Additions)

- (NSString *)hexString {
    UInt8 *buffer = (UInt8*)self.bytes;
    NSString *hexString = @"";
    for (NSUInteger i = 0; i < self.length; i++) {
        if (i == 0) {
          hexString = [hexString stringByAppendingFormat:@"%02X", buffer[i]];
        } else {
          hexString = [hexString stringByAppendingFormat:@" %02X", buffer[i]];
        }
    }
    return hexString;
}

- (UInt16)sw {
    UInt16 value = 0;
    if (self.length < 2)
        return value;
    [self getBytes:&value range:NSMakeRange(self.length - 2, 2)];
    return CFSwapInt16BigToHost(value);
}

- (NSData *)trailingTwoBytesTrimmed {
  if (self.length < 2)
    return nil;
    
  return  [self subdataWithRange:NSMakeRange(0, self.length - 2)];
}

@end
