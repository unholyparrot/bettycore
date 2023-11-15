process KRAKEN2 {
    tag "${meta.id}"
    label 'kraken2_mem_map'

    conda "bioconda::kraken2=2.1.3"
    
    input:
        tuple val(meta), path(reads)

    output:
        tuple val(meta), path("results.krona"), emit: results_for_krona
        tuple val(meta), path("*kraken2_report.txt")          , emit: report
        // то есть полностью осознанно игнорируем одноконцевые риды!
        tuple val(meta), path("*_kraken2_unclassified*.fq"),    emit: unclassified
        path "versions.yml"                                   , emit: versions
        // tuple val(sample_id), path("${sample_id}_kraken_unclassified_{1,2}.fq")
        // tuple val(sample_id), path("${sample_id}_kraken2.report")

    script:
        prefix = task.ext.prefix ?: "${meta.id}"

        // we need `--memory-mapping` to make the node alive

        """
        kraken2 \
            --report-zero-counts \
            --db ${params.kraken2_db} --threads ${task.cpus} \
            --report ${prefix}.kraken2_report.txt \
            --unclassified-out "${prefix}_kraken2_unclassified#.fq" \
            --memory-mapping \
            --paired ${reads[0]} ${reads[1]} \
            > kraken2.out

        cat kraken2.out | cut -f 2,3 > results.krona
        
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //' | sed 's/ Copyright.*//')
        END_VERSIONS
        """
}
