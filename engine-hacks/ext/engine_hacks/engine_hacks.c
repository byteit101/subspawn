#include "ruby/ruby.h"
#include "ruby/io.h"
#include "ruby/intern.h"

// global to store the thread local name to read for $? and $CHILD_STATUS
static VALUE status_holder;


// $? accessor. returns `Thread.current[status_holder[0]]`
static VALUE
get_CHILD_STATUS(ID _x, VALUE *_y)
{
	return rb_thread_local_aref(rb_thread_current(), SYM2ID(RARRAY_AREF(status_holder, 0)));
}

// overwrites old $? definition to our defintion, and save the new status thread local name
static VALUE
install_status(VALUE self, VALUE new_status)
{
	rb_define_virtual_variable("$?", get_CHILD_STATUS, 0);
	rb_define_virtual_variable("$CHILD_STATUS", get_CHILD_STATUS, 0);

	// reset, and save the new state
	rb_ary_clear(status_holder);
	new_status = rb_to_symbol(new_status);
	rb_ary_push(status_holder, new_status);

	// return the name, converted
	return new_status;
}

static VALUE
join_pipes(VALUE self, VALUE reader, VALUE writer)
{
	rb_io_set_write_io(reader, writer);

	// ensure flags are correct
	RFILE(writer)->fptr->mode |= FMODE_SYNC|FMODE_DUPLEX;
	RFILE(reader)->fptr->mode |= FMODE_SYNC|FMODE_DUPLEX;
	RFILE(writer)->fptr->mode &= ~FMODE_READABLE;
	RFILE(reader)->fptr->mode &= ~FMODE_WRITABLE;

	// not functional, but what IO.popen does as API
	rb_ivar_set(reader, rb_intern("@tied_io_for_writing"), writer);
	return reader;

	// TODO: we may need to worry that MRI io.c sets pipe_finalize?
}

void Init_engine_hacks(void)
{
	VALUE EngineHacks = rb_define_module("EngineHacks");
	VALUE EngineHacksMRI = rb_define_module_under(EngineHacks, "MRI");

	// hold the status in an array, so we can mark the array, and avoid fiddling with making
	// our own marking stuff for the GC. if we don't mark as gc, SEGV
	status_holder = rb_ary_new();
	rb_global_variable(&status_holder);

	// Exposed methods. Unsafe, do not call these directly, use the cruby.rb wrapper functions only!
	rb_define_singleton_method(EngineHacksMRI, "install_status!", install_status, 1);
	rb_define_singleton_method(EngineHacksMRI, "join_io", join_pipes, 2);

}
