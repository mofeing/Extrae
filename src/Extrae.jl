module Extrae

include("FFI.jl")
const Type = FFI.Type
const Value = FFI.Value

"""
    version()

Return the version of the underlying TRACE package.

Although an application may be compiled to a specific TRACE library, by using the appropiate shared library commands, the application may use a different TRACE library.
"""
function version()
    major = Ref(UInt32(0))
    minor = Ref(UInt32(0))
    rev = Ref(UInt32(0))

    FFI.Extrae_get_version(major, minor, rev)

    VersionNumber(major[], minor[], rev[])
end
export version

"""
    init()

Initialize the tracing library.

This routine is called automatically in different circumstances, which include:
- Call to MPI_Init when the appropriate instrumentation library is linked or preload with the application.
- Usage of the DynInst launcher.
- If either the `libseqtrace.so`, `libomptrace.so` or `libpttrace.so` are linked dynamically or preloaded with the application.

No major problems should occur if the library is initialized twice, only a warning appears in the terminal output noticing the intent of double initialization.
"""
init() = FFI.Extrae_init()
export init


"""
    isinitialized()

Return `true` if the instrumentation has been initialized and if so, which mechanism was the first to initialize it.
"""
isinitialized() = FFI.Extrae_is_initialized()
export isinitialized

"""
    finish()

Finalize the tracing library and dumps the intermediate tracing buffers onto disk.
"""
finish() = FFI.Extrae_fini()
export finish

"""
    flush()

Force the calling thread to write the events stored in the tracing buffers to disk.
"""
flush() = FFI.Extrae_flush()
export flush

"""
    instrumentation(state)

Turn on/off the instrumentation.
"""
instrumentation(state::Bool) = state ? restart() : shutdown()
export instrumentation

"""
Add a single timestampted event into the tracefile.

Some common uses of events are:
- Identify loop iterations (or any code block): Given a loop, the user can set a unique type for the loop and a value related to the iterator value of the loop. For example:

  ```c
    for (i = 1; i <= MAX_ITERS; i++)
    {
      Extrae_event (1000, i);
      [original loop code]
      Extrae_event (1000, 0);
    }
  ````

    The last added call to Extrae_event marks the end of the loop setting the event value to 0, which facilitates the analysis with Paraver.

- Identify user routines: Choosing a constant type (6000019 in this example) and different values for different routines (set to 0 to mark a "leave" event).

  ```c
    void routine1 (void)
    {
      Extrae_event (6000019, 1);
      [routine 1 code]
      Extrae_event (6000019, 0);
    }

    void routine2 (void)
    {
      Extrae_event (6000019, 2);
      [routine 2 code]
      Extrae_event (6000019, 0);
    }
  ```

- Identify any point in the application using a unique combination of type and value.
"""
event(type, value; counters::Bool=false) = (counters ? FFI.Extrae_eventandcounters : FFI.Extrae_event)(type, value)
event(events::Vector{Tuple{Type,Value}}; counters::Bool=false) = begin
    types = map(x -> x[1], events)
    values = map(x -> x[2], events)
    (counters ? FFI.Extrae_neventandcounters : FFI.Extrae_nevent)(length(events), Ref(types), Ref(values))
end
export event

"""
This routine adds to the Paraver Configuration File human readable information regarding type type and its values values.

If no values need to be decribed set nvalues to `0` and also set values and description_values to `NULL`.
"""
define_event(type::Type, desc::String) = FFI.Extrae_define_event_type(type, Base.cconvert(Cstring(desc)), 0, Nothing, Nothing)
define_event(type::Type, desc::String, values::Vector{Tuple{Value,String}}) = begin
    nvalues = length(values)
    _values = map(x -> x[1], values)
    _descs = map(x -> x[2], values)
    FFI.Extrae_define_event_type(type, Base.cconvert(desc), nvalues, Ref(_values), Ref(_descs))
end

"""
    counters()

Emit the value of the active hardware counters set.
"""
counters() = FFI.Extrae_counters()

"""
    previous_hwc_set()

Switch to the previous hardware counter set defined in the XML file.
"""
previous_hwc_set() = FFI.Extrae_previous_hwc_set()

"""
    next_hwc_set()

Switch to the following hardware counter set defined in the XML file.
"""
next_hwc_set() = FFI.Extrae_next_hwc_set()

"""
    set_tracing_tasks()

Select the range of tasks (not threads!) to store information from in the tracefile.
"""
set_tracing_tasks(interval::UnitRange{UInt32}) = FFI.Extrae_set_tracing_tasks(interval.start::UInt32, interval.stop::UInt32)

"""
    setoption(options)

Configure tracing options at runtime. The options parameter has to be a bitwise or combination of the following options, depending on the user's needs:
- EXTRAE_CALLER_OPTION Dumps caller information at each entry or exit point of the MPI routines. Caller levels need to be configured at XML.
- `EXTRAE_HWC_OPTION` Activates hardware counter gathering.
- `EXTRAE_MPI_OPTION` Activates tracing of MPI calls.
- `EXTRAE_MPI_HWC_OPTION` Activates hardware counter gathering in MPI routines.
- `EXTRAE_OMP_OPTION` Activates tracing of OpenMP runtime or outlined routines.
- `EXTRAE_OMP_HWC_OPTION` Activates hardware counter gathering in OpenMP runtime or outlined routines.
- `EXTRAE_UF_HWC_OPTION` Activates hardware counter gathering in the user functions.
"""
setoption(options::FFI.Options) = FFI.Extrae_set_options(options)

"""
    network_counters()

Emit the value of the network counters if the system has this capability (Only available for systems with Myrinet GM/MX networks).
"""
network_counters() = FFI.Extrae_network_counters()

"""
    network_routes(task)

Emit the network routes for an specific `task`.
"""
network_routes(task) = FFI.Extrae_network_routes(task)

"""
    user_function(enter)

Emit an event into the tracefile which references the source code (data includes: source line number, file name and function name).

If enter is 0 it marks an end (i.e., leaving the function), otherwise it marks the beginning of the routine. The user must be careful to place the call of this routine in places where the code is always executed, being careful not to place them inside if and return statements. The function returns the address of the reference.
```c
void routine1 (void)
{
  Extrae_user_function (1);
  [routine 1 code]
  Extrae_user_function (0);
}

void routine2 (void)
{
  Extrae_user_function (1);
  [routine 2 code]
  Extrae_user_function (0);
}
```

In order to gather performance counters during the execution of these calls, the user-functions tag and its counters have to be both enabled int section :ref:`sec:XMLSectionUF`.

# Warning

Note that you need to compile your application binary with debugging information (typically the `-g` compiler flag) in order to translate the captured addresses into valuable information such as function name, file name and line number.
"""
user_function(enter) = FFI.Extrae_user_function(enter)

end
