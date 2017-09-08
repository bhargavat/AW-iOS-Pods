/* ********************************************************************
 * Copyright (C) 2012-2015 VMware, Inc. All rights reserved.
 * -- VMware Confidential
 * ********************************************************************/

/*
 * HookExportTable.c --
 *
 * Export table - Classic
 * A part of global symbol table is export table.
 * It is a table of nlist structures.
 * The value field of nlist structure contains address of symbol.
 * We add the relocation offset to value field to get the absolute address
 *
 * Export table - Compressed
 * LC_DYLD_INFO load command contains information to access compressed export table.
 * Fields of interest are export-off, export-size.
 * In Compressed format, symbols are encoded as a tree and corresponding offsets and flags
 * are encoded using unsigned LEB128 encoding
 */
#include <mach-o/nlist.h>

#include "HookCoreInternal.h"

#define MAX_NAME 512
#define ERR_NOT_AVAILABLE  -2
#define ERR_NOT_FOUND      -1


/**
 * Offsets are encoded as unsigned LEB128 values
 *
 * See http://en.wikipedia.org/wiki/LEB128
 */
static uint64_t
decodeUleb128(const uint8_t **curr, const uint8_t *end)
{
   uint64_t result = 0;
   int bit = 0;
   do {
      if (*curr == end) {
         return 0;
      }
      uint64_t slice = **curr & 0x7f;
      if (bit >= 64 || ((slice << bit) >> bit) != slice) {
         return 0;
      } else {
         result |= (slice << bit);
         bit += 7;
      }
   } while (*(*curr)++ & 0x80);
   return result;
}


/**
 * Recursively walks the trie to find the offset.
 */
static ptrdiff_t
recursiveSearchInExportNode(const uint8_t *const start,
                            const uint8_t *curr,
                            const uint8_t *const end,
                            char *cumulativeString,
                            unsigned int cumulativeStringSize,
                            int curStrOffset,
                            const char *funcName)
{
   // first check for a terminal entry
   const uint8_t terminalSize = *curr++;
   if (funcName[curStrOffset] == '\0') {                 // is end of funcName
      if (terminalSize != 0) {                           // is end of symbol name
         (void)decodeUleb128(&curr, end);                // skip terminal flags
         return (ptrdiff_t)decodeUleb128(&curr, end);    // return terminal address
      } else {
         return ERR_NOT_FOUND;
      }
   }

   // now check for children if any
   const uint8_t *children = curr + terminalSize;
   const uint8_t childrenCount = *children++;
   const uint8_t *s = children;
   for (uint8_t i = 0; i < childrenCount; ++i) {
      // load string suffix
      int edgeStrLen = 0;
      while (*s != '\0') {
         assert(curStrOffset + edgeStrLen < cumulativeStringSize);
         cumulativeString[curStrOffset + edgeStrLen] = *s++;
         ++edgeStrLen;
      }
      assert(curStrOffset + edgeStrLen < cumulativeStringSize);
      cumulativeString[curStrOffset + edgeStrLen] = *s++;

      // load offset to child
      intptr_t childNodeOffet = (intptr_t)decodeUleb128(&s, end);

      // if the string matches so far, check child
      if (memcmp(&funcName[curStrOffset], &cumulativeString[curStrOffset], edgeStrLen) == 0) {
         return recursiveSearchInExportNode(start,
                                  start + childNodeOffet,
                                  end,
                                  cumulativeString,
                                  cumulativeStringSize,
                                  curStrOffset + edgeStrLen,
                                  funcName);
   }
   }

   return ERR_NOT_FOUND;
}


/**
 * Searches for function name in compressed export table of image represented by linkedit info.
 */
static ptrdiff_t
searchFuncInCompressedExportTable(const HCMachoContext *info, const char *funcName)
{
   if (!info->dyldInfo || info->dyldInfo->export_off == 0) {
      return ERR_NOT_AVAILABLE;
   }

      uint8_t *start = (uint8_t *)info->virtAddrOfLinkeditSegment +
                              info->dyldInfo->export_off - info->fileoffsetOfLinkeditSegment;
      uint8_t *end = &start[info->dyldInfo->export_size];
      char cumulativeString[MAX_NAME];
      return recursiveSearchInExportNode(start, start, end,
                                         cumulativeString,
                                         sizeof cumulativeString,
                                         0, funcName);
   }


/**
 * Searches linearly for function name in the classic export table.
 */
static void *
searchFuncInClassicExportTable(const HCMachoContext *info, const char *funcName)
{
   assert(info->exportedSymbolIndex + info->exportedSymbolCount <= info->symbolTableSize);
   for (int i = 0; i < info->exportedSymbolCount; i++) {
      STRUCT_NLIST *symbolTableEntry = &info->symbolTable[info->exportedSymbolIndex + i];

      const char *symbolName;
      uint32_t stringTableOffset = symbolTableEntry->n_un.n_strx;
      if (stringTableOffset > 0) {
         assert(stringTableOffset < info->stringTableSize);
         symbolName = &info->stringTable[stringTableOffset];
      } else {
         symbolName = "";
      }

      if (strcmp(symbolName, funcName) == 0) {
         if ((symbolTableEntry->n_desc & N_ARM_THUMB_DEF) != 0) {
            return (void *)((symbolTableEntry->n_value + info->relocOffset) | 1);
         } else {
            return (void *)(symbolTableEntry->n_value + info->relocOffset);
         }
      }
   }
   return NULL;
}


/**
 * \brief Find an exported function pointer
 *
 * Find the address of a exported function in a mach-o module.
 *
 * \param context mach-o module context to search
 * \param funcName function name to search for
 * \return function pointer or NULL if not found.
 */
void *
HookCoreGetExportedFunction(const HCMachoContext *context, const char *funcName)
{
   // first look in the more efficient compressed LINKEDIT section
   ptrdiff_t offset = searchFuncInCompressedExportTable(context, funcName);
   if (offset != ERR_NOT_AVAILABLE) {
         //return (uint8_t *)context->baseAddress + offset;
      }

   // fall back on a linear search of the classic export table
   return searchFuncInClassicExportTable(context, funcName);
}
