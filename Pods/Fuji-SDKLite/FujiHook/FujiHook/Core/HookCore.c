/* ********************************************************************
 * Copyright (C) 2012-2015 VMware, Inc. All rights reserved.
 * -- VMware Confidential
 * ********************************************************************/

/* HookCore.c --
 *
 * Core component of hooking subsystem which is shared between logger
 * and HookManager. Its purpose is to install level-one hooks which are provided
 * by HookManager or logger. Installs the hooks by traversing the import
 * table of all the loaded modules in the process address-space. For any
 * module loaded later by the process, it registers a handler which is
 * called by the loader when a module is loaded.
 */

#include "HookCoreInternal.h"
#include <dlfcn.h>


/**
 * Initialize the HCMachoContext struct from a loaded library
 * \param header address of the library header
 * \param context the context info describing the library
 */
static void
InitHCMachoContext(const struct mach_header *header, HCMachoContext *context)
{
   // sanity check arguments
#ifdef __LP64__
   assert(header->magic == MH_MAGIC_64);
#else
   assert(header->magic == MH_MAGIC);
#endif

   // start clean
   memset(context, 0x00, sizeof(*context));

   context->baseAddress = (void *)header;

   ptrdiff_t fileOffsetOfDataSegment = 0;
   intptr_t virtualAddressOfDataSegment = 0;

   // process all the load commands
   uint32_t cmd_count = header->ncmds;
   const struct load_command *cmd = (const struct load_command *)((void*)header +
                                                                  sizeof(STRUCT_MACH_HEADER));
   for (int i = 0; i < cmd_count; i++) {
      switch (cmd->cmd) {
         case LC_SEGMENT_64:{
#ifdef __LP64__
            struct segment_command_64 *segment = (struct segment_command_64 *)cmd;
            if (strcmp(segment->segname, SEG_LINKEDIT) == 0) {
               context->virtAddrOfLinkeditSegment = segment->vmaddr + context->relocOffset;
               context->fileoffsetOfLinkeditSegment = segment->fileoff;
            } else if ((strcmp(segment->segname, SEG_DATA) == 0) ||
                       (strcmp(segment->segname, "__DATA_CONST") == 0)) {
               virtualAddressOfDataSegment = segment->vmaddr + context->relocOffset;
               fileOffsetOfDataSegment = segment->fileoff;
            } else if (strcmp(segment->segname, SEG_TEXT) == 0) {
               context->relocOffset = (ptrdiff_t)(context->baseAddress - segment->vmaddr);
            }

            struct section_64 *sect_itr = (struct section_64 *)((char *)cmd + sizeof(struct segment_command_64));
            for (int i = 0; i < segment->nsects; i++) {
               if ((sect_itr->flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS) {

                  //Initialize the SymbolPointerTableInfo for lazy symbol section.
                  context->lazySymbolPointerTable.start = (intptr_t *)(virtualAddressOfDataSegment + sect_itr->offset - fileOffsetOfDataSegment);
                  context->lazySymbolPointerTable.indirectTableIndex = sect_itr->reserved1;
                  context->lazySymbolPointerTable.numEntries = (uint32_t)(sect_itr->size / sizeof(intptr_t));
               }
               if ((sect_itr->flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {

                  //Initialize the SymbolPointerTableInfo for non-lazy symbol section.
                  context->nonLazySymbolPointerTable.start  = (intptr_t *)(virtualAddressOfDataSegment + sect_itr->offset - fileOffsetOfDataSegment);
                  context->nonLazySymbolPointerTable.indirectTableIndex = sect_itr->reserved1;
                  context->nonLazySymbolPointerTable.numEntries = (uint32_t)(sect_itr->size / sizeof(intptr_t));
               }
               sect_itr++;
            }
            break;
#else
            /* LC_SEGMENT_64 not support in 32 bit mode */
            assert(false);
#endif
         }
         case LC_SEGMENT: {
#ifndef __LP64__
            struct segment_command *segment = (struct segment_command *)cmd;
            if (strcmp(segment->segname, SEG_LINKEDIT) == 0) {
               context->virtAddrOfLinkeditSegment = segment->vmaddr + context->relocOffset;
               context->fileoffsetOfLinkeditSegment = segment->fileoff;
            } else if ((strcmp(segment->segname, SEG_DATA) == 0) ||
                       (strcmp(segment->segname, "__DATA_CONST") == 0)) {
               virtualAddressOfDataSegment = segment->vmaddr + context->relocOffset;
               fileOffsetOfDataSegment = segment->fileoff;
            } else if (strcmp(segment->segname, SEG_TEXT) == 0) {
               context->relocOffset = (ptrdiff_t)(context->baseAddress - segment->vmaddr);
            }

            struct section *sect_itr = (struct section *)((char *)cmd + sizeof(struct segment_command));
            for (int i = 0; i < segment->nsects; i++) {
               if ((sect_itr->flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS) {

                  //Initialize the SymbolPointerTableInfo for lazy symbol section.
                  context->lazySymbolPointerTable.start = (intptr_t *)(virtualAddressOfDataSegment + sect_itr->offset -
                                                   fileOffsetOfDataSegment);
                  context->lazySymbolPointerTable.indirectTableIndex = sect_itr->reserved1;
                  context->lazySymbolPointerTable.numEntries = sect_itr->size / sizeof(intptr_t);
               }
               if ((sect_itr->flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {

                  //Initialize the SymbolPointerTableInfo for non-lazy symbol section.
                  context->nonLazySymbolPointerTable.start  = (intptr_t *)(virtualAddressOfDataSegment + sect_itr->offset -
                                                           fileOffsetOfDataSegment);
                  context->nonLazySymbolPointerTable.indirectTableIndex = sect_itr->reserved1;
                  context->nonLazySymbolPointerTable.numEntries = sect_itr->size / sizeof(intptr_t);
               }
               sect_itr++;
            }
            break;
#else
            /* LC_SEGMENT not support in 64 bit mode */
            assert(false);
#endif
         }
         case LC_SYMTAB: {
            // save away the symbol table location and size
            struct symtab_command *sym_cmd = (struct symtab_command *)cmd;

            if (sym_cmd->nsyms) {
               ptrdiff_t segOffset = sym_cmd->symoff - context->fileoffsetOfLinkeditSegment;
               context->symbolTable = (STRUCT_NLIST *)(context->virtAddrOfLinkeditSegment + segOffset);
               context->symbolTableSize = sym_cmd->nsyms;
            }

            if (sym_cmd->strsize) {
               ptrdiff_t segOffset = sym_cmd->stroff - context->fileoffsetOfLinkeditSegment;
               context->stringTable = (const char *)(context->virtAddrOfLinkeditSegment + segOffset);
               context->stringTableSize = sym_cmd->strsize;
            }
            break;
         }
         case LC_DYSYMTAB: {
            struct dysymtab_command *dysym_cmd = (struct dysymtab_command *)cmd;

            if (dysym_cmd->nindirectsyms) {
               ptrdiff_t segOffset = dysym_cmd->indirectsymoff - context->fileoffsetOfLinkeditSegment;
               context->indirectTable = (const uint32_t *)(context->virtAddrOfLinkeditSegment + segOffset);
               context->indirectTableSize = dysym_cmd->nindirectsyms;
            }
            context->undefinedSymbolsCount = dysym_cmd->nundefsym;
            context->undefinedSymbolsIndex = dysym_cmd->iundefsym;
            context->exportedSymbolIndex = dysym_cmd->iextdefsym;
            context->exportedSymbolCount = dysym_cmd->nextdefsym;
            break;
         }
         case LC_DYLD_INFO:
         case LC_DYLD_INFO_ONLY: {
            context->dyldInfo = (struct dyld_info_command *)cmd;
            break;
         }
         default:
            break;
      }

      // On to the next load command
      cmd = (struct load_command *)(((char *)cmd) + cmd->cmdsize);
   }
}

/**
 * Callback registered with loader. This gets called for each loaded image.
 * \param mh address of the library header
 * \param slide ??
 */
static void
HookLibraryAddCallback(const struct mach_header *mh, intptr_t slide)
{
   /* Look up the image info */
   Dl_info info;
   memset(&info, 0, sizeof(info));
   if (dladdr(mh, &info) == 0) {
      return;
   }

   /*
    * The image name has a path component that is not represented in the libName
    * field of the hook. Locate the last '/' and truncate the string after it.
    */
   const char *imageName = rindex(info.dli_fname, '/');
   if (imageName) {
      imageName++;
   } else {
      imageName = info.dli_fname; // no '/' was found
   }

   /*
    * If the libName is an inital segment of the imageName then a match
    * is assumed. Note that imageName may have a suffix like .dylib.
    */
   size_t libLen = strlen(imageName);
   if (strstr(imageName, ".dylib")) {
      libLen -= 6;
   }

   // Initialize the HCMachoContext structure.
   HCMachoContext context;
   InitHCMachoContext(mh, &context);

   for (int i = 0; gHook[i].funcName != NULL; i++) {
      /*
       * If we are hooking any function exported by the current library,
       * find the original export now.
       */
      if (gHook[i].origAddress == NULL && strncmp(imageName, gHook[i].libName, libLen) == 0) {
         gHook[i].origAddress = HookCoreGetExportedFunction(&context, gHook[i].funcName);
      }

      // intercept any hooked functions that the loaded library calls
      HookCoreHookImportedFunction(&context, &gHook[i]);
   }
}

/**
 * Callback registered with loader. This gets called for each loaded image.
 * \param mh address of the library header
 * \param slide ??
 */
static void
HookLibraryRemoveCallback(const struct mach_header *mh, intptr_t slide)
{
   /* Look up the image info */
   Dl_info info;
   memset(&info, 0, sizeof(info));
   if (dladdr(mh, &info) == 0) {
      return;
   }

   /*
    * The image name has a path component that is not represented in the libName
    * field of the hook. Locate the last '/' and truncate the string after it.
    */
   const char *imageName = rindex(info.dli_fname, '/');
   if (imageName) {
      imageName++;
   } else {
      imageName = info.dli_fname; // no '/' was found
   }

   /*
    * If the libName is an inital segment of the imageName then a match
    * is assumed. Note that imageName may have a suffix like .dylib.
    */
   size_t libLen = strlen(imageName);
   if (strstr(imageName, ".dylib")) {
      libLen -= 6;
   }

   for (int i = 0; gHook[i].funcName != NULL; i++) {
      /*
       * If the libName is an inital segment of the imageName then a match
       * is assumed. Note that imageName may have a suffix like .dylib.
       */
      if (gHook[i].origAddress != NULL && strncmp(imageName, gHook[i].libName, libLen) == 0) {
         gHook[i].origAddress = NULL;
      }
   }
}

//#ifdef ENABLE_PROXY

/**
 * Expose InitHCMachoContext for unit testing.
 */
__attribute__((visibility("default")))
void _private_test_InitHCMachoContext(const struct mach_header *header, HCMachoContext *context)
{
   InitHCMachoContext(header, context);
}

/**
 * \brief Initiallization routine of the library.
 *
 * This method becomes the init method when static library is converted into a
 * dylib by the makefile. This is not static as clang will optimize it away.
 */
void __attribute__ ((constructor,visibility("default")))
HookCore_Init(void)
{
   // Ensure we're only called once
   static int initialized = false;
   if (initialized) {
      return;
   }
   initialized = true;

   // Register a handler for all current and future added modules.
   _dyld_register_func_for_add_image(HookLibraryAddCallback);

   // Register a handler for all removed modules.
   _dyld_register_func_for_remove_image(HookLibraryRemoveCallback);
}

//#endif
