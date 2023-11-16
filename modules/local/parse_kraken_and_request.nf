process PARSE_KRAKEN2_AND_REQUEST {
    tag "$meta.id"
    
    conda "conda-forge::ncbi-datasets-cli conda-forge::pandas=2.0.3 conda-forge::tqdm"

    input:
        tuple val(meta), path(kraken_report)
    
    output:
        tuple val(meta), path("${meta.id}_non_viral.tsv"), emit: non_viral
        tuple val(meta), path("${meta.id}_viral.tsv"),     emit: viral
    
    script:
        def api_key = params.ncbi_api_token ?: ''

        """
        parse_kraken_and_request.py \
            -in $kraken_report -prefix ${meta.id} \
            --workers ${task.cpus} --api_key $api_key --quiet 
        """
}
