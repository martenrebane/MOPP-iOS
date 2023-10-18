//
//  OpenLdap.m
//  CryptoLib
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

#import "OpenLdap.h"
#import "ldap.h"
#import "ResultSet.h"

@implementation OpenLdap

- (NSArray*)search:(NSString*)identityCode configuration:(MoppLdapConfiguration *)moppLdapConfiguration {
    NSString *certsPath = [self getLibraryCertsFolderPath];
    NSArray *result = nil;
    if (moppLdapConfiguration.LDAPCERTS != nil && [moppLdapConfiguration.LDAPCERTS count] > 0) {
        NSArray *ldapURLs = @[moppLdapConfiguration.LDAPPERSONURL, moppLdapConfiguration.LDAPCORPURL];
        NSArray<NSString*>* certs = [self getFilesInDirectory:certsPath];
        for (NSString *cert in certs) {
            for (NSString *url in ldapURLs) {
                result = [self searchWith:identityCode andUrl:url certificatePath:cert];
                if (result != nil && [result count] > 0) {
                    return result;
                }
            }
        }
    } else {
        result = [self searchWith:identityCode andUrl:moppLdapConfiguration.LDAPPERSONURL certificatePath:nil];
        if (result == nil || [result count] == 0) {
            result = [self searchWith:identityCode andUrl:moppLdapConfiguration.LDAPCORPURL certificatePath:nil];
        }
    }
    return result;
}

- (NSArray*)searchWith:(NSString*)identityCode andUrl:(NSString*)url certificatePath:(NSString*)certificatePath {

    LDAP *ldap;
    LDAPMessage *msg;
    const char *base = "c=EE";
    
    BOOL secureLdap = [[url lowercaseString] hasPrefix:@"ldaps"];
    
    NSCharacterSet* notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *filter;
    
    NSString *pnoeePrefix = secureLdap ? @"PNOEE-" : @"";
    NSString *wildcard = secureLdap ? @"" : @"*";
    
    if ([identityCode rangeOfCharacterFromSet:notDigits].location == NSNotFound && [identityCode length] == 11) {
        filter = [NSString stringWithFormat:@"(serialNumber=%@%@%@)", pnoeePrefix, identityCode, wildcard];
    } else if ([identityCode rangeOfCharacterFromSet:notDigits].location == NSNotFound) {
        filter = [NSString stringWithFormat:@"(serialNumber=%@)", identityCode];
    } else {
        filter = [NSString stringWithFormat:@"(cn=*%@*)", identityCode];
    }
    
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] resourcePath];
    
//    int debugLevel = -1;
//    ldap_set_option(NULL, LDAP_OPT_DEBUG_LEVEL, &debugLevel);

    int ldapReturnCode;
    if (secureLdap) {
        if (certificatePath == nil || [certificatePath length] == 0) {
            ldapReturnCode = ldap_set_option(NULL, LDAP_OPT_X_TLS_CACERTDIR, (void *)[bundlePath cStringUsingEncoding:NSUTF8StringEncoding]);
            
            if (ldapReturnCode != LDAP_SUCCESS) {
                fprintf(stderr, "ldap_set_option(LDAP_OPT_X_TLS_CACERTDIR): %s\n", ldap_err2string(ldapReturnCode));
                return @[];
            };
        } else {
            ldapReturnCode = ldap_set_option(NULL, LDAP_OPT_X_TLS_CACERTFILE, (void *)[certificatePath cStringUsingEncoding:NSUTF8StringEncoding]);
            
            if (ldapReturnCode != LDAP_SUCCESS) {
                fprintf(stderr, "ldap_set_option(LDAP_OPT_X_TLS_CACERTDIR): %s\n", ldap_err2string(ldapReturnCode));
                return @[];
            };
        }
    }
    
    const char *formattedFilter = [filter UTF8String];
    ldapReturnCode = ldap_initialize(&ldap, [url cStringUsingEncoding:NSUTF8StringEncoding]);
    NSDictionary *ldapResponse;
    if (secureLdap) {
        int ldap_version = LDAP_VERSION3;
        ldapReturnCode = ldap_set_option(ldap, LDAP_OPT_PROTOCOL_VERSION, &ldap_version);
        if (ldapReturnCode != LDAP_SUCCESS) {
            fprintf(stderr, "ldap_set_option(PROTOCOL_VERSION): %s\n", ldap_err2string(ldapReturnCode));
            ldap_unbind_ext_s(ldap, NULL, NULL);
        };
    }
    
    if (ldapReturnCode == LDAP_SUCCESS) {
        ldap_search_ext_s(ldap, base, LDAP_SCOPE_SUBTREE, formattedFilter, nil, 0, 0, 0, 0, 0, &msg);
        if (msg != NULL){
            ResultSet *resultSet = [[ResultSet alloc] initWithParser:ldap chain:msg];
            ldapResponse = [resultSet getResult];
        }
        ldap_msgfree(msg);
    }
    
    int ldapConnectionReset = 0;
    ldap_set_option(NULL, LDAP_OPT_X_TLS_NEWCTX, &ldapConnectionReset);
    if (ldapConnectionReset != LDAP_SUCCESS) {
        fprintf(stderr, "ldap_set_option(LDAP_OPT_X_TLS_NEWCTX): %s\n", ldap_err2string(ldapConnectionReset));
        return @[];
    };
    
    NSMutableArray *response = [NSMutableArray new];
    for (NSString* key in ldapResponse) {
        Addressee *ldapRow = [[Addressee alloc] init];
        id value = [ldapResponse objectForKey:key];
        for (NSString* innerKey in value) {
            if ([innerKey rangeOfString:@"userCertificate;binary"].length != 0) {
                id certValue = ([value objectForKey:innerKey]);
                SecCertificateRef certificate;
                if ([certValue isKindOfClass: [NSArray class]]) {
                    // Do nothing with mobile-id certificate
                } else {
                    certificate = (__bridge SecCertificateRef)(certValue);
                    ldapRow.cert = (__bridge NSData *)SecCertificateCopyData(certificate);
                }
            }
            
            if ([innerKey isEqual:@"cn"]) {
                id innerValue = [value objectForKey:innerKey];
                NSArray *cn = [innerValue componentsSeparatedByString:@","];
                if (cn.count > 1) {
                    ldapRow.surname = cn[0];
                    ldapRow.givenName = cn[1];
                    ldapRow.identifier = cn[2];
                } else {
                    ldapRow.identifier = cn[0];
                    ldapRow.type = @"E-SEAL";
                }
            }
        }
        
        if(ldapRow.cert != nil) {
            [response addObject: ldapRow];
        }
    }
    
    return response;
    
}

- (NSString*) getLibraryCertsFolderPath {
    NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if ([libraryPaths count] > 0) {
        NSString *libraryPath = libraryPaths[0];
        NSString *certsPath = [libraryPath stringByAppendingPathComponent:@"LDAPCerts"];
        return certsPath;
    }
    return nil;
}

- (BOOL)isDirectoryEmpty:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDirectory;
    BOOL directoryExists = [fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory];

    if (directoryExists) {
        NSError *error;
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
        
        if (!error) {
            return ([contents count] == 0);
        } else {
            NSLog(@"Error accessing directory: %@", [error localizedDescription]);
            return TRUE;
        }
    } else {
        NSLog(@"Directory %@ does not exist", directoryPath);
        return TRUE;
    }
}

- (NSArray<NSString*>*) getFilesInDirectory:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray<NSString *>* fileList = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        NSLog(@"Error getting files in directory %@: %@", directoryPath, [error localizedDescription]);
        return @[];
    } else {
        NSMutableArray<NSString *> *certFileList = [NSMutableArray array];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self ENDSWITH %@", @".pem"];
        
        for (NSString *fileName in fileList) {
            if ([predicate evaluateWithObject:fileName]) {
                NSString *fullPath = [directoryPath stringByAppendingPathComponent:fileName];
                [certFileList addObject:fullPath];
            }
        }
        
        return [certFileList copy];
    }
}

@end
