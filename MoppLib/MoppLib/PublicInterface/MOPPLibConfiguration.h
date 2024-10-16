//
//  Configuration.h
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

#import <Foundation/Foundation.h>

@interface MoppLibConfiguration : NSObject

@property (nonatomic, strong) NSString *SIVAURL;
@property (nonatomic, strong) NSString *TSLURL;
@property (nonatomic, strong) NSArray<NSString*> *TSLCERTS;
@property (nonatomic, strong) NSArray<NSString*> *LDAPCERTS;
@property (nonatomic, strong) NSString *TSAURL;
@property (nonatomic, strong) NSDictionary *OCSPISSUERS;
@property (nonatomic, strong) NSArray<NSString*> *CERTBUNDLE;
@property (nonatomic, strong) NSString *TSACERT;

- (id) initWithConfiguration:(NSString *)SIVAURL TSLURL:(NSString *)TSLURL TSLCERTS:(NSArray<NSString*> *)TSLCERTS LDAPCERTS:(NSArray<NSString*> *)LDAPCERTS TSAURL:(NSString *)TSAURL OCSPISSUERS:(NSDictionary *)OCSPISSUERS CERTBUNDLE:(NSArray<NSString*> *)CERTBUNDLE TSACERT:(NSString *)TSACERT;

@end
