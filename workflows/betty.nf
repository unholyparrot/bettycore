/*
 * Текущие попытки состоят в создании сколько-нибудь похожего на нормальный nf-core пайплайн по обработке данных
 */

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)

// 
// MODULE: Local to the pipeline
// 
include { KRAKEN2                                } from '../modules/local/kraken2'
include { KRONA_DB                               } from '../modules/local/krona_db'
include { KRONA                                  } from '../modules/local/krona'
include { SPADES_META as SPADES_UNCLASSIFIED     } from '../modules/local/spades_meta'
include { PARSE_KRAKEN2_AND_REQUEST               } from '../modules/local/parse_kraken_and_request'


//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK                            } from '../subworkflows/local/input_check'


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
    ch_versions = ch_versions.mix(FASTQC_TRIMMED.out.versions)

    // TODO: добавить объединение нескольких запусков по meta.run

    // Запускаем kraken2 для разбиения по таксономии
    KRAKEN2 (
        ch_raw_short_reads
    )
    ch_versions = ch_versions.mix(KRAKEN2.out.versions.first())

    // Проверяем переданный путь к базе данных krona
    if (params.krona_db){
            ch_krona_db = Channel.value(file( "${params.krona_db}" ))  // если путь есть, обращаемся к файлу пути
        } else {
            KRONA_DB ()  // если путь не передан, то самостоятельно устанавливаем krona db
            ch_krona_db = KRONA_DB.out.db
            ch_versions = ch_versions.mix(KRONA_DB.out.versions)
        }
    
    // делаем красивые html репорты кроны
    KRONA (
        KRAKEN2.out.results_for_krona,
        ch_krona_db
    )
    ch_versions = ch_versions.mix(KRONA.out.versions.first())

    // сразу после разбиения таксономии и составления картинок мы начинаем дальнейшие процедуры
    // сборка неклассифицированных ридов как метагенома 
    SPADES_UNCLASSIFIED (
        KRAKEN2.out.unclassified
    )
    ch_versions = ch_versions.mix(SPADES_UNCLASSIFIED.out.versions.first())

    // запуск пайплайна по запрашиванию геномов и характеризации покрытия для невирусных последовательностей

    // проведение теоретической оценки покрытия таксонов
    PARSE_KRAKEN2_AND_REQUEST (
        KRAKEN2.out.report
    )

    // NON_VIRAL_EVALUATION (
    //     PARSE_KRAKEN2_AND_REQUEST.out.non_viral
    // )

    // // запуск пайплайна по запрашиванию вирусных геномов, характеризации покрытия и попытке сборки для вирусных последовательностей 

    // VIRAL_EVALUATION (
    //     PARSE_KRAKEN2_AND_REQUEST.out.viral
    // )

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
    ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2.out.report.collect{it[1]}.ifEmpty([]))      // KRAKEN2 report


    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        [],
        []
    )

    multiqc_report = MULTIQC.out.report.toList()

}
