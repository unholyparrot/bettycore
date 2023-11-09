nextflow.enable.dsl=2

log.info """\
    B E T T Y Core - N F   P I P E L I N E
    ======================================
    table        : ${params.input}
    outdir       : ${params.output}
    """
    .stripIndent()

include { BETTY } from './workflows/betty'

workflow {
    BETTY ()
}
