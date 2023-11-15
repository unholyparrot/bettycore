process KRONA_DB {

    conda "bioconda::krona=2.7.1"

    output:
    path("taxonomy/taxonomy.tab"), emit: db
    path "versions.yml"          , emit: versions

    script:
    """
    ktUpdateTaxonomy.sh taxonomy

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ktImportTaxonomy: \$(ktImportTaxonomy 2>&1 | sed -n '/KronaTools /p' | sed 's/^.*KronaTools //; s/ - ktImportTaxonomy.*//')
    END_VERSIONS
    """
}