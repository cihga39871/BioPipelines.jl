_dep_docker() = CmdDependency(
    exec = `$(Config.path_docker)`,
    test_args = `--version`,
    validate_success = true
)


"""
	docker_volume_autoreplace(path_or_cmd...)

Bind docker volumns to paths or paths in `Cmd`. 

Paths in `Cmd` are determined by:  
- Not start with `-`;
- Start with `/` or `isdir` or `isfile`.

Return `(docker_volumn_args::Cmd, docker_paths::Vector{String})`

## Example

```julia
julia> docker_volumn_args, new_paths_or_cmds = docker_volume_autoreplace(
	"/home/abc/x.txt",
	"/home/abc/y/123.txt",
	"/db/db.sql",
	"/db/",
	`--ignore -f /tmp/xyz`
)

julia> docker_volumn_args
`-v /home/abc:/vol0 -v /home/abc/y:/vol1 -v /db:/vol2 -v /db/:/vol3 -v /tmp:/vol4`

julia> new_paths_or_cmds
5-element Vector{Union{Cmd, String}}:
 "/vol0/x.txt"
 "/vol1/123.txt"
 "/vol2/db.sql"
 "/vol3/"
 `--ignore -f /vol4/xyz`
```
"""
function docker_volume_autoreplace(path_or_cmd...)

	bindings = Dict{String,String}()
	docker_volumn_args = ``
	new_paths_or_cmds = Vector{Union{String,Cmd}}()
	n = 0
	for p in path_or_cmd
		n, new_path_or_cmd = _docker_volume_autoreplace!(bindings, docker_volumn_args, n, p)
		push!(new_paths_or_cmds, new_path_or_cmd)
	end
	return docker_volumn_args, new_paths_or_cmds
end

function _docker_volume_autoreplace!(bindings::Dict{String,String}, docker_volumn_args::Cmd, n::Int, path::AbstractString)
	abs_path = abspath(path)
	if isdir(abs_path)
		dir_path = abs_path
		base_name = ""
	else
		dir_path = dirname(abs_path)
		base_name = basename(abs_path)
	end
	if haskey(bindings, dir_path)
		volumn_path = bindings[dir_path]
	else
		volumn_path = "/vol$n"
		bindings[dir_path] = volumn_path
		push!(docker_volumn_args.exec, "-v")
		push!(docker_volumn_args.exec, "$dir_path:$volumn_path")
		n += 1
	end
	new_path = joinpath(volumn_path, base_name)
	return n, new_path
end
function _docker_volume_autoreplace!(bindings::Dict{String,String}, docker_volumn_args::Cmd, n::Int, cmd::Cmd)
	new_cmd = deepcopy(cmd)
	for (i, arg) in enumerate(cmd.exec)
		length(arg) == 0 && continue
		arg[1] == '-' && continue
		if arg[1] == '/' || isdir(arg) || isfile(arg)
			n, new_path = _docker_volume_autoreplace!(bindings::Dict{String,String}, docker_volumn_args::Cmd, n::Int, arg)
			new_cmd.exec[i] = new_path
		end
	end
	return n, new_cmd
end
