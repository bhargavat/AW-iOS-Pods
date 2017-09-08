/* ********************************************************************
 * Copyright (C) 2012-2015 VMware, Inc. All rights reserved.
 * -- VMware Confidential
 * ********************************************************************/

/* HookImportTable.c --
 *
 * Implementation of import-table patching.
 * Following is a brief of how import table hooking works:
 * 1. The function name has an entry in sybmol table.
 * 2. Import-table or import section points to starting index inside
 *    indirect-table, reserved1 field of section structure.
 * 3. Every entry inside import table has a corresponding entry in
 *    indirecttable.
 * 4. Indirect table entry contains corresponding index to symbol-table.
 * 5. So we linearly search through import-table looking for function_name,
 *    once found we patch entry.
 */

#include <sys/types.h>
#include <unistd.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <mach-o/loader.h>
#include <mach-o/getsect.h>
#include <string.h>

#include "HookCoreInternal.h"


/**
 * \brief Patch an entry in symbol-pointer-table.
 *
 * Replaces the function-pointer stored in symbol-pointer-table with the function
 * pointer to hooked function.
 *
 * \param info reference to library to search.
 * \param hook reference to hook to inject.
 * \param isLazy determines which table to patch.
 */
static void
patchSymbolPointerTableEntry(const HCMachoContext *machoContext,
                             const HCHookContext *hook,
                             bool isLazy) {
   const HCSymPtrTableInfo *table = NULL;

   if (isLazy) {
      table = &(machoContext->lazySymbolPointerTable);
   } else {
      table = &(machoContext->nonLazySymbolPointerTable);
   }

   for (int itr = 0; itr < table->numEntries ; itr++) {
      assert((table->indirectTableIndex+ itr) < machoContext->indirectTableSize);
      uint32_t indOffset = machoContext->indirectTable[table->indirectTableIndex + itr];

      assert((indOffset < machoContext->stringTableSize) ||
             (indOffset == INDIRECT_SYMBOL_LOCAL) ||
             (indOffset == INDIRECT_SYMBOL_ABS));

      if ((indOffset != INDIRECT_SYMBOL_ABS) &&
          (indOffset != INDIRECT_SYMBOL_LOCAL)) {
         const char *str;
         uint32_t offset = machoContext->symbolTable[indOffset].n_un.n_strx;
         if (offset > 0) {
         assert(offset < machoContext->stringTableSize);
            str = &machoContext->stringTable[offset];
         } else {
            /* offset == 0 is short hand for "" */
            str = "";
         }
         if (strcmp(hook->funcName, str) == 0) {
            table->start[itr] = (intptr_t)hook->hookAddress;
         }
      }
   }
}

/**
 * \brief Hook the imported function.
 *
 * Replace the function pointer to the real implementation with the pointer
 * to the generated stub.
 *
 * \param info reference to library to search
 * \param hook reference to hook to inject
 */
void
HookCoreHookImportedFunction(const HCMachoContext *context, const HCHookContext *hook)
{
   assert(context);
   assert(hook);

   //Patch the entry in Non-lazy symbol Pointer table.
   patchSymbolPointerTableEntry(context, hook, true);
   patchSymbolPointerTableEntry(context, hook, false);
}
