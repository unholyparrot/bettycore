#!/usr/bin/env python
# Пока сыроватый, но скрипт для параллельного запроса информации геномов различных таксономических единиц.

# TODO: требуется обработка исключений в случае пустой таблицы и\или отсутствия корневого вирусного таксона


import argparse
import subprocess
from io import StringIO

from queue import Queue
from threading import Thread
from concurrent.futures import ThreadPoolExecutor, as_completed

import pandas as pd
from tqdm.auto import tqdm


def parse_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument('-in', '--input',
                        type=str, required=True,
                        help="")
    
    parser.add_argument('-prefix', '--prefix',
                        type=str, required=True,
                        help="")
    
    parser.add_argument('--workers',
                        type=int, default=4)
    
    parser.add_argument('--api_key',
                        type=str, default="")
    
    parser.add_argument('-q', '--quiet',
                        action='store_true')
    
    parser.add_argument('--root_reads',
                        type=int, default=1000)
    
    parser.add_argument('--min_coverage',
                        type=float, default=30.0)

    return parser.parse_args()


def request_info(operation_id: int, tax_id: int, o_type: str):
    median_genome = 3e15
    if o_type == "non_viral":
        cmd_preset = f"""datasets summary genome taxon \
                        {tax_id} --reference {api_key} \
                        --as-json-lines | dataformat tsv genome \
                        --fields accession,organism-name,assmstats-total-sequence-len"""
    else:
        cmd_preset = f"""datasets summary virus genome taxon \
                        {tax_id} --refseq {api_key} \
                        --as-json-lines | dataformat tsv virus-genome \
                        --fields accession,virus-name,length"""

    call_exec = subprocess.run(cmd_preset, shell=True, capture_output=True)

    if call_exec.returncode == 0:
        pr = pd.read_csv(StringIO(call_exec.stdout.decode('utf-8')), sep="\t", comment='#', names=["Accession", "Name", "Length"], header=0)
        if pr.shape[0] != 0:
            median_genome = pr["Length"].median()
        else:
            median_genome = 5e15

    return operation_id, median_genome


def consume():
    while True:
        if not queue.empty():
            sample_from_queue = queue.get()
            if sample_from_queue is None:
                break
            else:
                operation_id, med_genome = sample_from_queue

                requested_med_genomes[operation_id] = med_genome


if __name__ == "__main__":
    args = parse_arguments()

    api_key = ""

    if args.api_key:
        api_key = f"--api-key {args.api_key}"

    df = pd.read_csv(args.input, sep="\t", 
                     names=["fraction", "Nroot", "Ntaxa", "rank", "taxID", "name"],
                     dtype={"fraction": float, "Nroot": int, "Ntaxa": int, "rank": str, "taxID": int, "name": str})
    
    # вручную костылим поиск вирусов в серединке
    viruses_position = df[df["taxID"] == 10239].index.values[0]  

    # разбиение на вирусные и не вирусные вхождения
    non_viral = df.loc[0: viruses_position - 1]
    viral = df.loc[viruses_position:]

    # по очереди итерируемся по последовательностям
    for suffix, sub_df in zip(["non_viral", "viral"], [non_viral, viral]):

        nv_target = sub_df[(sub_df["rank"] == "S") & (sub_df["Nroot"] > args.root_reads)]

        targets = nv_target["taxID"].values.tolist()

        queue = Queue()

        consumer = Thread(target=consume, daemon=True)
        consumer.start()

        requested_med_genomes = [10e15 for _ in range(len(targets))]

        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            p_bar = tqdm(total=len(targets), position=1, disable=args.quiet)
            future_to_files = {
                executor.submit(request_info, op_id, target, suffix): op_id for op_id, target in enumerate(targets)
            }

            for future in as_completed(future_to_files):
                current_operation = future_to_files[future]

                try:
                    data = future.result()
                except Exception as exc:
                    print(exc)
                else:
                    queue.put(data)
                    p_bar.update()
            p_bar.close()
        
        nv_target = nv_target.copy(deep=True)
        nv_target["med_length"] = requested_med_genomes
        nv_target["coverage"] = 2 * 100 * nv_target["Nroot"] / nv_target["med_length"]

        sub_sampled_targets = nv_target[nv_target["coverage"] >= args.min_coverage].copy(deep=True)
        sub_sampled_targets["name"] = sub_sampled_targets["name"].apply(lambda x: x.lstrip().replace(" ", "_"))

        sub_sampled_targets.to_csv(f"{args.prefix}_{suffix}.tsv", sep="\t", index=False)
