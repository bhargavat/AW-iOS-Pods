//  AWbase64.h
//  AirWatch
//
//  Created by Nolan Roberson on 3/11/13.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#ifndef AirWatch_AWbase64_h
#define AirWatch_AWbase64_h


char *aw_base64_encode(const unsigned char *data,
                    size_t input_length,
                    size_t *output_length);

unsigned char *aw_base64_decode(const char *data,
                             size_t input_length,
                             size_t *output_length);
#endif