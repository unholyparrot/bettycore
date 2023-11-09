/*
 * Текущие попытки состоят в создании сколько-нибудь похожего на нормальный nf-core пайплайн по обработке данных
 */


//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK                     } from '../subworkflows/local/input_check'


//
// MODULE: Directly from nf-core
//
include { FASTQC as FASTQC_RAW                   } from '../modules/nf-core/fastqc/main'

workflow BETTY {

    ch_versions = Channel.empty()  // Channel for versions output

    // 
    // Read input, validate files existence 

    INPUT_CHECK ()
    
    ch_raw_short_reads = INPUT_CHECK.out.raw_short_reads

    // 
    // Check the quality of short reads, then trim and filter  
    // 

    FASTQC_RAW (
        ch_raw_short_reads
    )

    ch_versions = ch_versions.mix(FASTQC_RAW.out.versions.first())


    
}