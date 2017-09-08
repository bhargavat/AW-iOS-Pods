/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */

#include <netdb.h>

#ifdef __APPLE__
#include <dns_sd.h>
#include <pthread.h>
typedef void (*getaddrinfo_async_callback)(int32_t status, struct addrinfo *res, void *context);
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Error codes returned by f5_logon function
#define	SESSION_NO_ERROR                0
#define	SESSION_AUTHENTICATION_ERROR    1
#define	SESSION_CONNECTION_ERROR        2
#define	SESSION_UNKNOWN_ERROR           -1


#ifndef HAVE_F5_DEVICEINFO
#define HAVE_F5_DEVICEINFO
     typedef struct
     {
          const char* 	szModel;          // null-terminated device model name
          const char* 	szOSVersion;      // null-terminated OS version
          const char*   szIMEI;           // null-terminated IMEI
          const char*   szMACAddress;     // null-terminated MAC address of Wi-Fi adapter
          const char*   szUniqueId;       // null-terminated unique device identifier
          const char*   szSerialNumber;   // null-terminated device serial number
          const char*   szVendorData;     // null-terminated vendor specific string
          const char*   szAppId;          // null-terminated application id
          const char*   szAppVersion;     // null-terminated application version
          char          isJailbroken;     // 0 - not jailbroken, 1 - jailbroken
     } F5_DeviceInfo;
#endif

#define MAX_SESSION_LEN  129

    /*
     * Library initialization.
     * Must be called before other f5_xxx functions.
     *
     * Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
     int f5_init();

    /*
     * Library deinitialization.
     * All existent tunneled connections will be closed
     *
     * Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
     int f5_deinit();


#ifdef __SECURE_TRANSPORT__
    /*
     * Certificate Verification Callback
     *
     * trustRef - a trust management object for the certificate used by a ssl session
     * context - pointer passed in call of f5_set_cert_verify function previously
     *
     * Return value:
     * Return 0 to indicate the certificate should be trusted, or non-zero otherwise
     * (in which case, the connection will fail)
     */
    typedef int (*cert_verify_fn)(SecTrustRef trustRef, void* context);
#else
    /*
     * Certificate Verification Callback
     *
     * szHost - hostname used for the session
     * a_cert_chain - pointer to certificate chain object (see 'f5_get_cert_der' and
     *  'f5_get_next' functions). The object will be freed after callback is done.
     * a_data_len - size of a_x509_data buffer
     * context - pointer passed in call of f5_set_cert_verify function previously
     *
     * Return value:
     * Return 0 to indicate the certificate should be trusted, or non-zero otherwise
     * (in which case, the connection will fail)
     */
    typedef int (*cert_verify_fn)(const char* szHost, const void* a_cert_chain, void* context);

    /*
     * Get X509 certificate from certificate chain object in der format
     *
     * a_cert_obj - certificate chain object received in certificate verification callback.
     * a_cert_len - output argument, it contains size of returned data.
     *
     * Return value: pointer to certificate in der format (size of data inside a_cert_len output variable).
     *  Lifetime of returned data is related to instance of a_cert_obj and will be freed automatically.
     */
#ifdef __cplusplus
    const uint8_t* f5_get_cert_der(const void* a_cert_obj, int &a_cert_len);
#endif

    /*
     * Get next certifiсate chain object. f5_get_cert_der should be called for returned value
     * to get certificate in der format.
     *
     * Return value: pointer to next certificate object, otherwise NULL
     */
    const void* f5_get_cert_next(const void* a_cert_obj);
#endif

    /*
     * Expired/Invalid Session Callback
     *
     * szSessionId - invalid/expired session id
     * context - pointer to the object passed in f5_set_invalid_session_callback
     * function
     *
     * Return value: none
     */
    typedef void (*invalid_session_fn)(const char* szSessionId, void* context);

    /*
     * Get version of the library
     *
     * Return value: string contained version of the library
     */
    const char* f5_get_version();

    /*
     * Set custom user agent string
     *
     * szUserAgent - new user agent string (value should be less than 1000 bytes).
     *
     * Return value: none
     */
    void f5_set_user_agent(const char* szUserAgent);

    /*
     * Define include and exclude scope based on dns suffixes. Each scope can contain
     * multiple host names and/or dns suffixes separated by comma.
     *
     * Behaviour:
     * If both include scope and exclude scope matches hostname, then
     * exclude scope has more priority. If hostname is not matched by any scope
     * (include, exclude) than hostname is going to exclude scope. Otherwise
     * hostname is going to matched scope. Defaults values: include scope = "*", exclude scope = "".
     *
     * Examples:
     * 1) Include everything, exclude subnet
     * include_scope = "*", exclude_scope = "*.domain.com"
     * 2) Include subnet, exclude everything
     * include_scope = "*.domain.com", exclude_scope = "" (empty)

     * include_scope - string contains comma separated host names or dns suffixes.
     * (for example, "*.mycompany.com"). NULL value is allowed, it doesn't
     * change current value.
     * exclude_scope - string contains comma separated host names/dns suffixes.
     * (for example, "*.org,*.net,www.test.com"). NULL value is allowed, it doesn't
     * change current value.
     *
     * Return value: Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
    int f5_set_dns_split_scope(const char* include_scope, const char* exclude_scope);

    /*
     * Logon to BIG-IP APM server
     *
     * host/port - address/port of APM server
     * username/password - user's credentials
     *
     * Return value:
     * Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
    int f5_logon(const char* host, int port, const char* username, const char* password);

    /*
     * Close established session
     *
     * Return value:
     * Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
    int f5_logout();

    /*
     * Sets information about device for use during user authentication.
     * Should be called before f5_logon function.
     *
     * devinfo - structure containing device specific information
     *
     * Return value:
     * Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
     int f5_set_device_info(F5_DeviceInfo* devinfo);

    /*
     * Get the session identifier that represents the currently established session or
     * previously set using f5_set_session
     *
     * a_session - pointer to buffer where the session is to be copied
     * a_session_length - length of the buffer
     * 
     * Return value:
     * Upon successful completion, a value of 0 is returned. "a_session" contains a
     * null-terminated identifier that represents the currently established session.
     *
     * A value of -1 is returned if the buffer is not large enough to contain the entire
     * session identifier.
     */
    int f5_get_session(char* a_session, size_t a_session_length);

    /*
     * Set information about the session for use during connection
     * 
     * Return value:
     * Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
    int f5_set_session(const char* a_server, int a_port, const char* a_sessionId);

    /*
     * Check session validity
     * 
     * Return value:
     * Upon successful completion, a value of 0 is returned. Otherwise, a value of -1
     * is returned indicating an unsuccessful request to server.
     *
     * Caller is expected to check the "a_ttl" value to determine session validity
     * even if the return value is 0.
     *
     * a_ttl is set to 0 if a_sessionId is invalid/expired, otherwise it is set 
     * to the session time to live value in msecs.
     */
    int f5_check_session(const char* a_server, int a_port,
                         const char* a_sessionId, unsigned long* a_ttl);

    /*
     * Register callback function to receive notification about logon session
     * expiration during connection establishment.
     *
     * If such callback is not registered, session can be checked by call of
     * f5_check_session function.
     * 
     * Note that the callback function is invoked from not main thread. So any
     * UI changes should not be done inside callback function and f5_* methods as
     * well.
     *
     * Return value:
     * Upon successful completion, a value of 0 is returned. Otherwise, a value of -1
     * is returned.
     */
    int f5_set_invalid_session_callback(invalid_session_fn invalid_sess_fn, void* context);

    /*
     * Register callback function to override SSL certificate verification (optional).
     *
     * If such callback is not registered, connections will fail if the SSL server
     * does not present a certificate signed by a trusted CA or if the certificate
     * presented is invalid.
     * 
     * The verification callback must return 0 to indicate the certificate should be
     * trusted, or non-zero otherwise (in which case, the connection will fail)
     *
     * Note that the callback function is invoked on the same thread as the one where
     * the connection is made.  It is possible that multiple callbacks are invoked
     * simultaneously if there are concurrent connections happening in multiple
     * threads.
     *
     * Return value:
     * Upon successful completion, a value of 0 is returned. Otherwise, a value of -1
     * is returned.
     */
    int f5_set_cert_verify(cert_verify_fn verify_fn, void* context);

    /*
     * Provide client identity information in PKCS#12 format as a
     * DER-encoded byte array (optional). If the identity is NULL, the identity previously 
     * set is cleared.
     *
     * Return value:
     * Upon successful completion, a value of 0 is returned. Otherwise, a value of -1
     * is returned.
     */
    int f5_set_identity_pkcs12(const void* a_pkcs12_data, int a_data_len, const char* a_password);

    /*
     * Establish tcp connection to server behinde BIG-IP server
     *
     * Return value:
     * Upon successful completion, a value of 0 is returned, otherwise, a -1 value
     */
    int f5_connect(int fd, const struct sockaddr *address, socklen_t address_len);

    /*
     * Same as standard 'gethostbyname' function (man gethostbyname)
     */
    struct hostent* f5_gethostbyname(const char *name);

    /*
     * Same as standard 'gethostbyname2' function (man gethostbyname2)
     */
    struct hostent* f5_gethostbyname2(const char *name, int af);

    /*
     * Same as standard 'gethostbyaddr' function (man gethostbyaddr)
     */
    struct hostent* f5_gethostbyaddr(const void *addr, socklen_t len, int type);

    /*
     * Same as standard 'getaddrinfo' function (man getaddrinfo)
     */
    int f5_getaddrinfo(const char *hostname,
                       const char *servname, 
                       const struct addrinfo *hints, 
                       struct addrinfo **res);

    /*
     * Same as standard 'freeaddrinfo' function (man getaddrinfo)
     */
    void f5_freeaddrinfo(struct addrinfo *ai);

#ifdef __APPLE__

#ifndef __XPC_H__
    typedef void* xpc_connection_t;
    typedef void* xpc_object_t;
    typedef void* xpc_handler_t;
#endif
    /*
     * Same as 'xpc_connection_send_message_with_reply' function
     */
    void f5_xpc_connection_send_message_with_reply(xpc_connection_t connection, xpc_object_t message, dispatch_queue_t targetq, xpc_handler_t handler);

    int32_t f5_getaddrinfo_async_start(mach_port_t *p, const char *nodename, const char *servname, const struct addrinfo *hints, getaddrinfo_async_callback callback, void *context);

#ifndef _DNS_SD_H
    typedef uint32_t DNSServiceFlags;
    typedef uint32_t DNSServiceProtocol;
    typedef int32_t  DNSServiceErrorType;

    typedef struct _DNSServiceRef_t *DNSServiceRef;

    typedef void (*DNSServiceGetAddrInfoReply)(DNSServiceRef sdRef,
        DNSServiceFlags flags,
        uint32_t interfaceIndex,
        DNSServiceErrorType errorCode,
        const char *hostname,
        const struct sockaddr *address,
        uint32_t ttl,
        void *context
    );

    typedef void (*DNSServiceGetAddrInfoReply)
    (
        DNSServiceRef sdRef,
        DNSServiceFlags flags,
        uint32_t interfaceIndex,
        DNSServiceErrorType errorCode,
        const char *hostname,
        const struct sockaddr *address,
        uint32_t ttl,
        void *context
    );
#endif

    // DNS related methods
    DNSServiceErrorType f5_DNSServiceGetAddrInfo (DNSServiceRef *sdRef,
                                                  DNSServiceFlags flags,
                                                  uint32_t interfaceIndex,
                                                  DNSServiceProtocol protocol,
                                                  const char *hostname,
                                                  DNSServiceGetAddrInfoReply callBack,
                                                  void *context);
    DNSServiceErrorType f5_DNSServiceProcessResult (DNSServiceRef sdRef);
    DNSServiceErrorType f5_DNSServiceSetDispatchQueue (DNSServiceRef sdRef, dispatch_queue_t queue);
    void f5_DNSServiceRefDeallocate(DNSServiceRef sdRef);
    int f5_DNSServiceRefSockFD(DNSServiceRef sdRef);

    // Streams related methods
    Boolean f5_CFReadStreamOpen(CFReadStreamRef stream);
    Boolean f5_CFWriteStreamOpen(CFWriteStreamRef stream);
    void f5_CFReadStreamClose(CFReadStreamRef stream);
    void f5_CFWriteStreamClose(CFWriteStreamRef stream);

    int f5_add_voip_host(const char* a_hostname, const uint16_t a_port);
    int f5_remove_voip_host(const char* a_hostname, const uint16_t a_port);
#endif

#ifdef __cplusplus
};
#endif