from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import json
import random
import time
import torch
import torch.nn as nn
import torch.optim
import tqdm
import os

import speech
import speech.loader as loader
import speech.models as models

# TODO, (awni) why does putting this above crash..
import tensorboard_logger as tb

def run_epoch(model, optimizer, train_ldr, it, avg_loss):

    model_t = 0.0; data_t = 0.0
    end_t = time.time()
    #tq = tqdm.tqdm(train_ldr)

    for idx, batch in enumerate(train_ldr):
        model.train()
        batch = list(batch) #this line isn't necessary w. py 2.7
        start_t = time.time()
        optimizer.zero_grad()

        loss = model.loss(batch)
        loss.backward()

        grad_norm = nn.utils.clip_grad_norm(model.parameters(), 200)
        loss = loss.data[0]

        optimizer.step()
        prev_end_t = end_t
        end_t = time.time()
        model_t += end_t - start_t
        data_t += start_t - prev_end_t

        exp_w = 0.99
        avg_loss = exp_w * avg_loss + (1 - exp_w) * loss

        tb.log_value('train_loss', loss, it)
        tb.log_value('avg_loss', avg_loss, it)
        tb.log_value('grad_norm', grad_norm, it)


        it += 1

    return it, avg_loss

def eval_dev(model, loader, preproc):
    losses = []; all_preds = []; all_labels = []

    model.eval()

    for batch in loader:
        batch = list(batch) #this line isn't necessary w. py 2.7
        preds = model.infer(batch)
        loss = model.loss(batch)
        losses.append(loss.data[0])
        all_preds.extend(preds)
        all_labels.extend(batch[1])

    model.set_train()

    loss = sum(losses) / len(losses)
    results = [(preproc.decode(l), preproc.decode(p))
               for l, p in zip(all_labels, all_preds)]
    cer = speech.compute_cer(results)
    print("Dev: Loss {:.3f}, CER {:.3f}".format(loss, cer))


    return loss, cer

def run(config):

    opt_cfg = config["optimizer"]
    data_cfg = config["data"]
    model_cfg = config["model"]

    # Loaders
    batch_size = opt_cfg["batch_size"]
    preproc = loader.Preprocessor(data_cfg["train_set"],
                  start_and_end=data_cfg["start_and_end"])
    train_ldr = loader.make_loader(data_cfg["train_set"],
                        preproc, batch_size)
    dev_ldr = loader.make_loader(data_cfg["dev_set"],
                        preproc, batch_size)

    # Model
    model = restore_or_init_model(config, preproc)

    print("input_dim size: ", preproc.input_dim)
    print("preproc.vocab_size: ", preproc.vocab_size)

    model.cuda() if torch.cuda.is_available() else model.cpu()

    # Optimizer - (julian) - changed this to Adam
    #assert opt_cfg.get("momentum") is None, "Adam does not accept `momentum` parameter"
    optimizer = torch.optim.Adam(model.parameters(),
                    lr=opt_cfg["learning_rate"])

    run_state = (0, 0)
    best_so_far = float("inf")
    for e in range(opt_cfg["epochs"]):
        start = time.time()

        run_state = run_epoch(model, optimizer, train_ldr, *run_state)

        msg = "Epoch {} completed in {:.2f} (s)."
        print(msg.format(e, time.time() - start))

        dev_loss, dev_cer = eval_dev(model, dev_ldr, preproc)

        # Log for tensorboard
        tb.log_value("dev_loss", dev_loss, e)
        tb.log_value("dev_cer", dev_cer, e)

        speech.save(model, preproc, config["save_path"])

        # Save the best model on the dev set
        if dev_cer < best_so_far:
            best_so_far = dev_cer
            speech.save(model, preproc,
                    config["save_path"], tag="best")

def restore_or_init_model(config, preproc):
    """Restores the model if `config['save_path']` has a model available."""

    expdir = config['save_path']
    model_cfg = config["model"]

    model_fn = None
    model_fp = None

    for path, subdirs, files in os.walk(expdir):
        for file in files:

            if speech.utils.io.MODEL in file:

                model_fn = file.split("/")[-1]

                #no tag used when the model is best
                if model_fn == speech.utils.io.MODEL:
                    assert model_fp is None, "Multiple model.pth files present in `config['save_path']`"
                    model_fp = file

    #init model randomly
    model_class = eval("models." + model_cfg["class"])
    model = model_class(preproc.input_dim,
                        preproc.vocab_size,
                        model_cfg)

    if model_fp is not None:
        #load saved weights
        weights = torch.load(model_fp)
        model.load_state_dict(weights)

    return model





def _train(config_fp, deterministic):
    """Run the same functionality as if __main__ from within a function"""
    with open(config_fp, 'r') as fid:
        config = json.load(fid)

    random.seed(config["seed"])
    torch.manual_seed(config["seed"])

    tb.configure(config["save_path"])

    use_cuda = torch.cuda.is_available()

    if use_cuda and deterministic:
        torch.backends.cudnn.enabled = False
    run(config)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
            description="Train a speech model.")

    parser.add_argument("config",
        help="A json file with the training configuration.")
    parser.add_argument("--deterministic", default=False,
        action="store_true",
        help="Run in deterministic mode (no cudnn). Only works on GPU.")
    args = parser.parse_args()

    _train(args.config, args.deterministic)
