from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import editdistance

def compute_cer(results):
    """
    Arguments:
        results (list): list of ground truth and
            predicted sequence pairs.

    Returns the CER for the full set.
    """
    dist = sum(editdistance.eval(label, pred)
                for label, pred in results)
    total = sum(len(label) for label, _ in results)
    return dist / total


def dist_total(results):
    """

    Arguments:
        results (list): list of ground truth and
            predicted sequence pairs.

    return the dist and total as calculated in compute_cer() above

    Reasoning - doesn't require caching of predictions for entire dev set
    as in the original implementation
    """
    dist = sum(editdistance.eval(label, pred)
                for label, pred in results)
    total = sum(len(label) for label, _ in results)

    return dist, total


