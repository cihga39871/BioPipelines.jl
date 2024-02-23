_dep_minimap2() = CmdDependency(
    exec = `$(Config.path_minimap2)`,
    test_args = `--version`,
    validate_success = true
)

function check_minimap2_index(inputs, outputs)
    fasta = inputs["REF"]
	build_minimap2_index(fasta)
end

function has_minimap2_index(fasta, index=fasta * ".mmi")
	in_building_file = fasta * ".minimap2-building"
	while isfile(in_building_file)
		sleep(2)
	end
	sleep(rand())
	while isfile(in_building_file)
		sleep(2)
	end
	return isfile(index)
end
function build_minimap2_index(fasta, index=fasta * ".mmi"; force::Bool=false, present::String="map-ont")
	if !force && has_minimap2_index(fasta)
		return true
	end
	in_building_file = fasta * ".minimap2-building"
	is_success = false
	try
		touch(in_building_file)
		run(`$dep_minimap2 -x asm20 -d $index $fasta`)
		run(`$dep_samtools faidx $fasta`) # cannot use gzip/bgzip, freebayes not compatible
		is_success = true
	catch e
		rethrow(e)
		@error Pipelines.timestamp() * "Cannot build minimap2 index for $fasta"
	finally
		rm(in_building_file)
	end
	return is_success
end

_prog_minimap2_index() = JuliaProgram(
	name = "Minimap2 Index",
	id_file = ".minimap2-index",
	cmd_dependencies = [dep_minimap2, dep_samtools],
	inputs = ["FASTA", "PRESENT" => "map-ont" => String],
	validate_inputs = inputs -> begin
		check_dependency_file(inputs["FASTA"])
	end,
	outputs = "INDEX" => "<FASTA>.mmi",
	validate_outputs = outputs -> begin
		isfile(outputs["INDEX"])
	end,
	main = (inputs, outputs) -> begin
		build_minimap2_index(inputs["FASTA"], outputs["INDEX"], present=inputs["PRESENT"])
		outputs
	end
)

_prog_minimap2() = CmdProgram(
	name = "Minimap2 Mapping",
	id_file = ".minimap2",
	cmd_dependencies = [dep_minimap2, dep_samtools],

	inputs = [
		"FASTA", 
		"REF", 
		"PRESENT" => "map-ont",
		:THREADS => Int => 1, 
		"OTHER_ARGS" => Config.args_minimap2 => Cmd],
	validate_inputs = inputs -> begin
		check_dependency_file(inputs["FASTA"]) &&
		check_dependency_file(inputs["REF"])
	end,

	outputs = "BAM" => "<FASTQ>.bam",

	validate_outputs = outputs -> begin
		isfile(outputs["BAM"])
	end,


	cmd = pipeline(
		`$dep_minimap2 -x PRESENT -a -t THREADS OTHER_ARGS REF FASTA`, 
		# `$SAMTOOLS view -h -G 4`, # remove unmapped
		
		# Use awk here:
		#    Minimap2 generates bam records' quality column $11 as * (because input is fasta),
		# and deepvariant cannot recognize *.
		#    For comparibility of deepvariant, 
		# we assign quality of all bases to J (highest for illumina) by using 
		# {$11 = $10; gsub(/./, "J", $11)
		#    No change to lines if 
		# (1) header line ($1 ~ /^@/)
		# (2) SEQ is marked as * (do not know why it happens) ($10 == "*")
		# (3) QUAL is not * (for comparibility of normal bam file) 
		# `awk -F '\t' 'OFS="\t" {if ($1 ~ /^@/ || $10 == "*" || $11 != "*") {print} else {$11 = $10; gsub(/./, "J", $11); print} }'`,
		
		`$dep_samtools view -@ THREADS -O bam -o BAM`),

    arg_forward      = ["THREADS" => :ncpu]
)