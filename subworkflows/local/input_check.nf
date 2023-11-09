//
// Check input samplesheet and get read channels
//

// #TODO: устроить проверку всех обрабатываемых исключений, пока что взято as is

// just took from random nf-core pipeline
// checks wether the input extension is correct 
// вообще можно и в скриптик обернуть питоновский, так тоже немало кто делает!
def hasExtension(it, extension) {
    it.toString().toLowerCase().endsWith(extension.toLowerCase())
}

workflow INPUT_CHECK {
    main:
        if(hasExtension(params.input, ".csv")){
            ch_input_rows = Channel
                .from(file(params.input))
                .splitCsv(header: true)
                .map {
                    row -> 
                        if (row.size() >= 4) {
                            def id = row.sample
                            def run = row.run
                            def sr1 = row.short_reads_1 ? file(row.short_reads_1, checkIfExists: true) : false
                            def sr2 = row.short_reads_2 ? file(row.short_reads_2, checkIfExists: true) : false 
                            // Check if given combination is valid
                            if (run != null && run == "") exit 1, "ERROR: Check input samplesheet -> Column 'run' contains an empty field."
                            if (!sr1 || !sr2) exit 1, "Invalid input samplesheet: short reads can not be empty."
                            return [ id, run, sr1, sr2 ]
                        } else {
                            exit 1, "Input samplesheet contains row with ${row.size()} column(s). Expects at least 4."
                        }
                }
            ch_raw_reads = ch_input_rows
            .map {
                id, run, sr1, sr2 -> 
                    def meta = [:]
                        meta.id = id
                        meta.run = run
                    return [ meta, [ sr1, sr2 ]]
            }
        } else {
            exit 1, "An input CSV file with sample pathes and description is expected"
        }
        
        // Ensure run IDs are unique within samples (also prevents duplicated sample names)
        // пока не могу разобраться, почему тут не используется exit, но используется error :O 
        ch_input_rows
            .groupTuple(by: 0)
            .map { id, run, sr1, sr2 -> if( run.size() != run.unique().size() ) { { error("ERROR: input samplesheet contains duplicated sample or run IDs (within a sample)! Check samplesheet for sample id: ${id}") } } }
    
        // тут добавить проверку ncbi_api_token и иных ключей, а затем обернуть это в 

    emit:
        raw_short_reads = ch_raw_reads
}
