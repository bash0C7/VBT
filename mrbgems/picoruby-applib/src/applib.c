#if defined(PICORB_VM_MRUBY)

// mruby implementation (future support)

#elif defined(PICORB_VM_MRUBYC)

#include <mrubyc.h>

/**
 * Applib.version
 * Returns the version number of this application-specific mrbgem.
 * Returns an integer value (e.g., 100 = v1.0.0).
 */
static void
c_applib_version(mrbc_vm *vm, mrbc_value *v, int argc)
{
  // Return the version number as an integer
  mrbc_value ret = mrbc_integer_value(100);
  SET_RETURN(ret);
}

/**
 * Applib mrbgem initialization function
 * Automatically called when the mrbgem is loaded.
 * Register class methods here.
 */
void
mrbc_applib_init(mrbc_vm *vm)
{
  // Define the class
  mrbc_class *applib_class = mrbc_define_class(vm, "Applib", mrbc_class_object);

  // Register class method: version
  mrbc_define_method(vm, applib_class, "version", c_applib_version);
}

#endif
