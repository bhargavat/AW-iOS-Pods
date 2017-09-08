//
//  ProxyAuthTokenHelper.m
//  AirWatch
//
//  Created by Vishal Patel on 7/9/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#include "ProxyAuthTokenHelper.h"

#include <time.h>
#include <pthread.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define TOKEN_VALIDITY_WINDOW 2 * 60   //Time in epoch seconds
#define TOKEN_SIZE 32

static char * previousToken;
static char * currentToken;
static time_t tokenGeneratedTime;
static pthread_mutex_t tokenMutex;


void initTokenGenerator()
{
    srand((unsigned)time(NULL));
    pthread_mutex_init(&tokenMutex, NULL);
}

static
int isTokenExpired()
{
    time_t now;
    time(&now);
    return (NULL == currentToken) ||
        (difftime(now, tokenGeneratedTime) >= TOKEN_VALIDITY_WINDOW);
}

char * getProxyAuthToken()
{
    pthread_mutex_lock(&tokenMutex);
    
    if (isTokenExpired())
    {
        if (previousToken) free(previousToken);
        previousToken = currentToken;
       //Ref. ISDK-168220 initialize token buffer.
        char* memoryAllocationForCurrentToken = malloc(sizeof(char) * (TOKEN_SIZE +1));
        if (memoryAllocationForCurrentToken == NULL) {
            return NULL;
        }else {
            currentToken = memoryAllocationForCurrentToken;
        }
        memset(currentToken,0x0,TOKEN_SIZE +1);
        for (int i = 0; i < TOKEN_SIZE; i++) {
            sprintf(&currentToken[i],"%x",arc4random());
        }
        tokenGeneratedTime = time(NULL);
    }
    
    pthread_mutex_unlock(&tokenMutex);
    
    return currentToken;
}

int isTokenValid(const char * tokenToVerify)
{
    pthread_mutex_lock(&tokenMutex);
    int isEqualToCurrentToken = 0;
    if (tokenToVerify != NULL &&
        currentToken != NULL) {
        isEqualToCurrentToken = strncmp(tokenToVerify, currentToken, strlen(currentToken)) == 0;
    }
    
    int isEqualToPreviousToken = 0;
    if (previousToken != NULL &&
        tokenToVerify != NULL) {
        isEqualToPreviousToken = strncmp(tokenToVerify, previousToken, strlen(previousToken)) ==0;
    }
    
    pthread_mutex_unlock(&tokenMutex);
    return (isEqualToCurrentToken || isEqualToPreviousToken);
}
