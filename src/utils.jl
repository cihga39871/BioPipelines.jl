
function merge_tables(file_paths::Vector; file_labels::Union{Nothing, Vector} = nothing, label_name::Symbol = :label, args_to_CSV_read::Tuple = ())
    dfs = CSV.read.(file_paths, DataFrame; args_to_CSV_read...)
    if file_labels isa Vector
        if length(file_labels) != length(file_paths)
            error("length(file_labels) != length(file_paths)")
        end
        for (i, df) in enumerate(dfs)
            file_label = file_labels[i]
            insertcols!(df, 1, label_name => file_label)
            if i > 1
                append!(dfs[1], df, promote=true)
            end
        end
    else
        for (i, df) in enumerate(dfs)
            if i > 1
                append!(dfs[1], df, promote=true)
            end
        end
    end
    return dfs[1]
end
