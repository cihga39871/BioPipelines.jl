_dep_docker_check_deepvariant() = CmdDependency(
    exec = `$(Config.path_docker)`,
    test_args = `images $(Config.docker_img_deepvariant)`,
    validate_stdout = x -> occursin("deepvariant", x)
)


_prog_deepvariant() = JuliaProgram(
	name = "DeepVariant Variant Calling",
	id_file = ".deepvariant",
	cmd_dependencies = [dep_docker_check_deepvariant],  # it checks both docker and deepvariant
	inputs = [
		"MODEL_TYPE" => "HYBRID_PACBIO_ILLUMINA" => String,
		"REF" => String,
		"BAM" => String,
		:THREADS => 1 => Int,
		"OTHER_ARGS" => Config.args_deepvariant => Cmd],
	outputs = [
		"VCF" => "<BAM>.vcf",
		"GVCF" => "<BAM>.g.vcf"
	],
	main = (i,o) -> begin
		docker_volumn_args, new_paths_or_cmds = Common.docker_volume_autoreplace(i["REF"], i["BAM"], i["OTHER_ARGS"], o["VCF"], o["GVCF"])
		ref, bam, other_args, vcf, gvcf = new_paths_or_cmds
		run(`$dep_docker run $docker_volumn_args 
			$(Config.docker_img_deepvariant) /opt/deepvariant/bin/run_deepvariant
			--model_type $(i["MODEL_TYPE"])
			--ref $ref
			--reads $bam
			--output_vcf $vcf
			--output_gvcf $gvcf
			--num_shards $(i["THREADS"])
			$other_args`)
		return o
	end,
    arg_forward = ["THREADS" => :ncpu]
)