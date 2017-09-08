//
//  AWMethodSwizzle.h
//  Swizzle
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#ifndef __Swizzle__AWMethodSwizzle__
#define __Swizzle__AWMethodSwizzle__

#include <objc/runtime.h>

#endif /* defined(__Swizzle__AWMethodSwizzle__) */

void MethodSwizzle(Class c, SEL originalSEL, SEL overrideSEL, BOOL isClassMethod);
void MethodSwizzleBetweenClasses(Class c, SEL originalSEL, Class d, SEL overrideSEL, BOOL isClassMethod);

// If there was an issue, then Null is returned
Class * getClasses(Protocol *protocol, int *classCount);
