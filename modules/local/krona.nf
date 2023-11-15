process KRONA {
    tag "${meta.id}"

    conda "bioconda::krona=2.7.1"

    input:
    tuple val(meta), path(report)
    path(taxonomy_file), stageAs: 'taxonomy.tab'

    output:
    tuple val(meta), path("*.html") , emit: html
    path "versions.yml"             , emit: versions

    script:
    """
    TAXONOMY=\$(find -L . -name '*.tab' -exec dirname {} \\;)

    ktImportTaxonomy ${report} -tax \$TAXONOMY/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ktImportTaxonomy: \$(ktImportTaxonomy 2>&1 | sed -n '/KronaTools /p' | sed 's/^.*KronaTools //; s/ - ktImportTaxonomy.*//')
    END_VERSIONS
    """
}
