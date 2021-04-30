//
//  MoppLibPersonalData.m
//  MoppLib
//
/*
 * Copyright 2017 - 2021 Riigi Infosüsteemi Amet
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

#import "MoppLibPersonalData.h"

@implementation MoppLibPersonalData

- (NSString *)fullName {
  NSMutableString *name = [NSMutableString new];
  
  if (self.givenNames.length > 0) {
    [name appendString:self.givenNames];
  }
  
  if (self.surname.length > 0) {
    if (name.length > 0) {
      [name appendString:@" "];
    }
    [name appendString:self.surname];
  }
  
  return name;
}

- (NSString *)givenNames {
  NSMutableString *name = [NSMutableString new];
  if (self.firstNameLine1.length > 0) {
    [name appendString:self.firstNameLine1];
  }
  
  if (self.firstNameLine2.length > 0) {
    if (name.length > 0) {
      [name appendString:@" "];
    }
    [name appendString:self.firstNameLine2];
  }
  
  return name;
}
@end
