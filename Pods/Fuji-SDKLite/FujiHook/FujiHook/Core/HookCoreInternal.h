/* ********************************************************************
 * Copyright (C) 2012-2015 VMware, Inc. All rights reserved.
 * -- VMware Confidential
 * ********************************************************************/

/* HookCoreInternal.h --
 *
 * Internal Interface of HookCore.
 */

#ifndef _HOOKING_INTERNAL_H_
#define _HOOKING_INTERNAL_H_

#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>

#include "HookCore.h"


/* Handle the different structures between 32 bit and 64 bit modes */
#if __LP64__
typedef struct nlist_64 STRUCT_NLIST;
typedef struct mach_header_64 STRUCT_MACH_HEADER;
#else
typedef struct nlist STRUCT_NLIST;
typedef struct mach_header STRUCT_MACH_HEADER;
#endif


typedef struct {
   intptr_t *start;                         // Start address of symbol pointer table.
   uint32_t numEntries;                     // Number of entries in symbol Pointer Table.
   uint32_t indirectTableIndex;             //Index of the corresponding entries in indirecttable.
} HCSymPtrTableInfo;

typedef struct {
   void *baseAddress;                        // base address of a library in memory
   const char *stringTable;                  // pointer to read stringTable table
   uint32_t stringTableSize;                 // size of stringTable in bytes
   STRUCT_NLIST *symbolTable;                // pointer to symbol table
   uint32_t symbolTableSize;
   const uint32_t *indirectTable;            // pointer to the indirect symbol table in dynamic symbol table.
   uint32_t indirectTableSize;
   HCSymPtrTableInfo nonLazySymbolPointerTable; //Information for Non-lazy symbol pointer table.
   HCSymPtrTableInfo lazySymbolPointerTable;   //Information for Lazy symbol pointer table.
   uint32_t undefinedSymbolsCount;           // number of undefined symbols in the symbol table
   uint32_t undefinedSymbolsIndex;           // position of undefined symbols in the symbol table
   uint32_t exportedSymbolIndex;             // index of first export symbol in symbol taable,
   uint32_t exportedSymbolCount;             // number of export symbols.
   struct dyld_info_command *dyldInfo;       // pointer to dyld_info segment.
   intptr_t virtAddrOfLinkeditSegment;       // virtual Address of linkedit segment.
   ptrdiff_t fileoffsetOfLinkeditSegment;    // File offset of linkedit segment in memory.
   ptrdiff_t relocOffset;                    // Offset by which image is displaced from its prefferred load address
                                             // by the loader.
} HCMachoContext;

void *HookCoreGetExportedFunction(const HCMachoContext *context, const char *funcName);
void HookCoreHookImportedFunction(const HCMachoContext *context, const HCHookContext *hook);

#endif
