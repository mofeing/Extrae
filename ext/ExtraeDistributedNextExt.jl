module ExtraeDistributedNextExt

using Extrae
using DistributedNext

# value taken at random
# might be interesting to add a preference for overriding
const EXTRAEJL_CODE_DISTRIBUTED_STATE::Extrae.FFI.Type = 81221

@enum DistributedState::Extrae.FFI.Value begin
    DistributedStateNone = 0
    DistributedStateWorkerStarting = 1
    DistributedStateWorkerExiting = 2
end

function __init__()
    Extrae.register(
        EXTRAEJL_CODE_DISTRIBUTED_STATE,
        "Distributed State",
        [
            DistributedStateNone,
            DistributedStateWorkerStarting,
            DistributedStateWorkerExiting,
        ],
        ["None", "Worker Starting", "Worker Exiting"],
    )

    DistributedNext.add_worker_starting_callback() do
        Extrae.emit(EXTRAEJL_CODE_DISTRIBUTED_STATE, DistributedStateWorkerStarting)
    end
    DistributedNext.add_worker_started_callback(extrae_dist_start_cb) do
        Extrae.emit(EXTRAEJL_CODE_DISTRIBUTED_STATE, DistributedStateWorkerNone)
    end
    DistributedNext.add_worker_exiting_callback(extrae_dist_exiting_cb) do
        Extrae.emit(EXTRAEJL_CODE_DISTRIBUTED_STATE, DistributedStateWorkerExiting)
    end
    DistributedNext.add_worker_exited_callback(extrae_dist_exited_cb) do
        Extrae.emit(EXTRAEJL_CODE_DISTRIBUTED_STATE, DistributedStateNone)
    end
end

end
