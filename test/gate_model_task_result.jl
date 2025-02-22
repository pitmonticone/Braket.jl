using Braket, Braket.Observables, Braket.IR, Test, JSON3
using Braket: ResultTypeValue


exact_results = [(Probability(0), [0.5, 0.5]),
                 (StateVector(), [complex(0.70710678, 0), 0, 0, complex(0.70710678, 0)]),
                 (Expectation(Braket.Observables.Y(), 0), 0.0),
                 (Variance(Braket.Observables.Y(), 0), 0.1),
                 (Amplitude("00"), Dict("00"=>complex(0.70710678, 0))),
                 (AdjointGradient(2.0 * Observables.X() * Observables.X(), [0, 1], ["p_1", "p_2"]), Dict(:expectation=>0.1, :gradient=>Dict("p_1"=>0.2, "p_2"=>0.3)))]

zero_shots_result(task_mtd, add_mtd) = Braket.GateModelTaskResult(
    Braket.header_dict[Braket.GateModelTaskResult],
    nothing,
    nothing,
    map(r->ResultTypeValue(ir(r[1], Val(:JAQCD)), r[2]), exact_results),
    [0,1],
    task_mtd,
    add_mtd,
)

non_zero_shots_result(task_mtd, add_mtd) = Braket.GateModelTaskResult(
    Braket.header_dict[Braket.GateModelTaskResult],
    nothing,
    Dict("011000"=>0.9999999999999982),
    nothing,
    collect(0:5),
    task_mtd,
    add_mtd)

@testset "GateModelQuantumTaskResult" begin
    c = CNot(Circuit(), 0, 1)
    action = Braket.Program(c)
    @testset for (shots, result) in zip([0, 100], [zero_shots_result, non_zero_shots_result])
        task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", shots, "arn1", nothing, nothing, nothing, nothing, nothing)
        additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
        r = result(task_metadata, additional_metadata)
        g = Braket.format_result(r)
        @test g isa Braket.GateModelQuantumTaskResult
        @test sprint(show, g) == "GateModelQuantumTaskResult\n"
        if shots == 0
            for er in exact_results
                @test g[er[1]] == er[2]
            end
        end
    end
    task_metadata = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", 0, "arn1", nothing, nothing, nothing, nothing, nothing)
    additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
    result = Braket.GateModelQuantumTaskResult(task_metadata, JSON3.read(JSON3.write(additional_metadata), Braket.AdditionalMetadata), nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
    @test JSON3.read("{\"task_metadata\": $(JSON3.write(task_metadata)), \"additional_metadata\": $(JSON3.write(additional_metadata))}", Braket.GateModelQuantumTaskResult) == result
end

@testset "shots>0 results computation" begin
    measurements = [
        [0, 0, 1, 0],
        [1, 1, 1, 1],
        [1, 0, 0, 1],
        [0, 0, 1, 0],
        [1, 1, 1, 1],
        [0, 1, 1, 1],
        [0, 0, 0, 1],
        [0, 1, 1, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 1],
    ]
    mat = [1 0; 0 -1]
    ho = Braket.Observables.HermitianObservable(mat)
    samp = ir(Braket.Sample(ho, Int[2]), Val(:JAQCD))
    action = Braket.Program(Braket.header_dict[Braket.Program],
                            [Braket.IR.CNot(0, 1, "cnot"), Braket.IR.CNot(2, 3, "cnot")],
                            [Braket.IR.Probability([1], "probability"),
                             Braket.IR.Expectation(["z"], nothing, "expectation"),
                             Braket.IR.Variance(["x", "x"], [0, 2], "variance"),
                             samp,
                             Braket.IR.Sample(["z"], [1], "sample"),
                             Braket.IR.Sample(["x", "y"], [1, 2], "sample"),
                             Braket.IR.Sample(["z"], nothing, "sample"),
                            ],
                            [])
    task_metadata_shots = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", length(measurements), "arn1", nothing, nothing, nothing, nothing, nothing)
    additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
    task_result = Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult],
        measurements,
        nothing,
        nothing,
        [0, 1, 2, 3],
        task_metadata_shots,
        additional_metadata,
    )
    quantum_task_result = Braket.format_result(task_result)
    @test quantum_task_result.values[1] ≈ [0.6, 0.4]
    @test quantum_task_result.values[2] ≈ [0.4, 0.2, -0.2, -0.4]
    @test quantum_task_result.values[3] ≈ 1.11111111111
    @test quantum_task_result.values[4] ≈ [1.0, 1.0, -1.0, 1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0]
    @test quantum_task_result.result_types[1].type == Braket.IR.Probability([1], "probability")
    @test quantum_task_result.result_types[2].type == Braket.IR.Expectation(["z"], nothing, "expectation")
    

    action = Braket.Program(Braket.header_dict[Braket.Program],
                            [Braket.IR.H(0, "h"), Braket.IR.H(1, "h"), Braket.IR.H(2, "h"), Braket.IR.H(3, "h")],
                            [Braket.IR.Sample("z", [1], "sample"),
                             Braket.IR.Sample(["x", "y"], [1, 2], "sample"),
                             Braket.IR.Sample("z", nothing, "sample"),
                            ],
                            [])
    task_metadata_shots = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", length(measurements), "arn1", nothing, nothing, nothing, nothing, nothing)
    additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
    task_result = Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult],
        measurements,
        nothing,
        nothing,
        [0, 1, 2, 3],
        task_metadata_shots,
        additional_metadata,
    )
    quantum_task_result = Braket.format_result(task_result)
    @test quantum_task_result.values[1] ≈ [1, -1, 1, 1, -1, -1, 1, -1, 1, 1]
    @test quantum_task_result.values[2] ≈ [-1, 1, 1, -1, 1, 1, 1, 1, 1, 1]
    @test quantum_task_result.values[3] ≈ [[1, -1, -1, 1, -1, 1, 1, 1, 1, 1], [1, -1, 1, 1, -1, -1, 1, -1, 1, 1], [-1, -1, 1, -1, -1, -1, 1, -1, 1, 1], [1, -1, -1, 1, -1, -1, -1, -1, 1, -1]] 

    @testset "result without measurements or measurementProbabilities" begin
        task_metadata_shots = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", length(measurements), "arn1", nothing, nothing, nothing, nothing, nothing)
        additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
        task_result = Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult],
            nothing,
            nothing,
            nothing,
            [0, 1, 2, 3],
            task_metadata_shots,
            additional_metadata,
        )
        @test_throws ErrorException Braket.format_result(task_result)
    end
    @testset "bad result type in results for shots > 0" begin
        action = Braket.Program(Braket.header_dict[Braket.Program], [Braket.IR.CNot(0, 1, "cnot"), Braket.IR.CNot(2, 3, "cnot")], [Braket.IR.DensityMatrix([1,3], "densitymatrix")], [])
        task_metadata_shots = Braket.TaskMetadata(Braket.header_dict[Braket.TaskMetadata], "task_arn", length(measurements), "arn1", nothing, nothing, nothing, nothing, nothing)
        additional_metadata = Braket.AdditionalMetadata(action, nothing, nothing, nothing, nothing, nothing, nothing)
        task_result = Braket.GateModelTaskResult(Braket.header_dict[Braket.GateModelTaskResult],
            measurements,
            nothing,
            nothing,
            [0, 1, 2, 3],
            task_metadata_shots,
            additional_metadata,
        )
        @test_throws ErrorException Braket.format_result(task_result)
    end
end
