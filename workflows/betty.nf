/*
 * Текущие попытки состоят в создании сколько-нибудь похожего на нормальный nf-core пайплайн по обработке данных
 */

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)

// 
// MODULE: Local to the pipeline
// 


//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK                     } from '../subworkflows/local/input_check'


//
// MODULE: Directly from nf-core
//
include { FASTQC as FASTQC_RAW                   } from '../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_TRIMMED               } from '../modules/nf-core/fastqc/main'
include { FASTP                                  } from '../modules/nf-core/fastp/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS            } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { MULTIQC                                } from '../modules/nf-core/multiqc/main'


workflow BETTY {

    ch_versions = Channel.empty()  // Channel for versions output

    // 
    // Read input, validate files existence 

    INPUT_CHECK ()
    
    ch_raw_short_reads = INPUT_CHECK.out.raw_short_reads

    // 
    // Check the quality of short reads, then trim and filter  
    // 

    // да, я ошибался, плагин нормальный :)
    FASTQC_RAW (
        ch_raw_short_reads
    )
    ch_versions = ch_versions.mix(FASTQC_RAW.out.versions.first())

    FASTP (
        ch_raw_short_reads,
        [],
        params.fastp_save_trimmed_fail,
        []
    )
    
    ch_short_reads_prepped = FASTP.out.reads
    ch_versions = ch_versions.mix(FASTP.out.versions.first())




    // Запускаем FASTQC после обработки ридов
    FASTQC_TRIMMED (
        FASTP.out.reads
    )
    ch_versions.mix(FASTQC_TRIMMED.out.versions)

    // экспорт информации о версиях программного обеспечения
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    // подготовка файлов для MULTIQC
    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.zip.collect{it[1]}.ifEmpty([]))      // FASTQC RAW reads
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.collect{it[1]}.ifEmpty([]))          // FASTP (adapter and quality trimming)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_TRIMMED.out.zip.collect{it[1]}.ifEmpty([]))  // FASTQC clean reads


    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        [],
        []
    )

    multiqc_report = MULTIQC.out.report.toList()

}
