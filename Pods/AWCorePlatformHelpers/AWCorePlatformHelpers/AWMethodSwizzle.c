//
//  AWMethodSwizzle.c
//  Swizzle
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#include "AWMethodSwizzle.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void MethodSwizzle(Class c, SEL originalSEL, SEL overrideSEL, BOOL isClassMethod)
{
    Method originalMethod = (!isClassMethod) ? class_getInstanceMethod(c, originalSEL) : class_getClassMethod(c, originalSEL);
    Method overrideMethod = (!isClassMethod) ? class_getInstanceMethod(c, overrideSEL) : class_getClassMethod(c, overrideSEL);
    // there will be cases where a class does not have a method implemented and thus we should not swizzle a method to a NULL pointer because then the app will crash.
    if(originalMethod == NULL || overrideMethod == NULL)
        return;
    
    if (isClassMethod) {
        c = object_getClass((id)c);
    }
    
    if(class_addMethod(c, overrideSEL, method_getImplementation(overrideMethod), method_getTypeEncoding(overrideMethod))) {
        // This newMethod is the needed swizzled method to be added to the current Class that will override the NSObject swizzle method
        Method newMethod = class_getInstanceMethod(c, overrideSEL);
        method_exchangeImplementations(originalMethod, newMethod);
    }
    else {
        method_exchangeImplementations(originalMethod, overrideMethod);
    }
}

void MethodSwizzleBetweenClasses(Class c, SEL originalSEL, Class d, SEL overrideSEL, BOOL isClassMethod)
{
    Method originalMethod = (!isClassMethod) ? class_getInstanceMethod(c, originalSEL) : class_getClassMethod(c, originalSEL);
    Method overrideMethod = (!isClassMethod) ? class_getInstanceMethod(d, overrideSEL) : class_getClassMethod(d, overrideSEL);
    // there will be cases where a class does not have a method implemented and thus we should not swizzle a method to a NULL pointer because then the app will crash.
    if(originalMethod == NULL || overrideMethod == NULL)
        return;
    
    if (isClassMethod) {
        c = object_getClass((id)c);
        d = object_getClass((id)d);
    }
    
    if(class_addMethod(c, overrideSEL, method_getImplementation(overrideMethod), method_getTypeEncoding(overrideMethod))) {
        // This newMethod is the needed swizzled method to be added to the current Class that will override the NSObject swizzle method
        Method newMethod = class_getInstanceMethod(c, overrideSEL);
        method_exchangeImplementations(originalMethod, newMethod);
    }
    else {
        method_exchangeImplementations(originalMethod, overrideMethod);
    }
    
}


Class * getClasses(Protocol *protocol, int *classCount)
{
    *classCount = 0;
    int numClasses = objc_getClassList(NULL, 0);
    
    if (numClasses > 0 )
    {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        Class *protocolConformingClasses = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses/16);
        
        if (classes == NULL || protocolConformingClasses == NULL) {
            return NULL;
        }
        
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class c = classes[i];
            if (class_conformsToProtocol(c, protocol)) {
                protocolConformingClasses[*classCount] = c;
                *classCount = *classCount + 1;
            }
        }
        
        free(classes);
        return protocolConformingClasses;
    }
    
    return NULL;
}
