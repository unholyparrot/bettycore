process SPADES_META {
    tag "$meta.id"

    conda "bioconda::spades=3.15.3"

    input:
        tuple val(meta), path(reads)
    
    output:
            tuple val(meta), path("SPAdes-*_scaffolds.fasta"), emit: assembly
            path "SPAdes-*.log",                               emit: log
            path "SPAdes-*_contigs.fasta.gz",                  emit: contigs_gz
            path "SPAdes-*_scaffolds.fasta.gz",                emit: assembly_gz
            path "SPAdes-*_graph.gfa.gz",                      emit: graph
            path "versions.yml",                               emit: versions
    
    script:
        def args = task.ext.args ?: ''  // запрашиваем аргументы из modules.config
        maxmem = task.memory.toGiga()   // так как spades бывает требователен к памяти, запрашиваем память напрямую из base.config
        prefix = task.ext.prefix ?: "${meta.id}"

        """
        metaspades.py \
            --threads "${task.cpus}" --memory $maxmem \
            -1 ${reads[0]} -2 ${reads[1]} \
            -o spades
        
        mv spades/assembly_graph_with_scaffolds.gfa SPAdes-${prefix}_graph.gfa
        mv spades/scaffolds.fasta SPAdes-${prefix}_scaffolds.fasta
        mv spades/contigs.fasta SPAdes-${prefix}_contigs.fasta
        mv spades/spades.log SPAdes-${prefix}.log
        gzip "SPAdes-${prefix}_contigs.fasta"
        gzip "SPAdes-${prefix}_graph.gfa"
        gzip -c "SPAdes-${prefix}_scaffolds.fasta" > "SPAdes-${prefix}_scaffolds.fasta.gz"

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python --version 2>&1 | sed 's/Python //g')
            metaspades: \$(metaspades.py --version | sed "s/SPAdes genome assembler v//; s/ \\[.*//")
        END_VERSIONS
        """
}
