#!/usr/bin/env python

# This script analyzes a bunch of files and tries to find files that are very
# similar and are candidates to be merged.
#  - Sameer Gauria - Jun 13th 2012

import difflib
import sys
import argparse
#import pprint
#import itertools
#import glob

def text_compare(text1, text2, thresh, accuracy=0):
  isjunk=None
  sqm = difflib.SequenceMatcher(isjunk, text1, text2)
  ratio = sqm.real_quick_ratio()
  if ratio > thresh and accuracy >= 1:
    ratio = sqm.quick_ratio()
    if ratio > thresh and accuracy >= 2:
      ratio = sqm.ratio()
  return ratio

def compare_files(files, thresh, accuracy=0):
  lf = len(files)
  results = []
  for i in range(lf):
    f1 = open(files[i], 'r')
    f1r = f1.read();
    for j in range(i+1,lf):
      f2 = open(files[j], 'r')
      f2r = f2.read();
      score = text_compare(f1r, f2r, thresh, accuracy)
      if (score > thresh):
	results.append((score, files[i], files[j]))
      f2.close()
    f1.close()
  maxwidth = max(map(len, files))
  for i in sorted(results):
    print "%10f\t%s\t%s"%(i[0], str(i[1]).ljust(maxwidth), str(i[2]).ljust(maxwidth))

def main():
  parser = argparse.ArgumentParser(description="Take a list of files and try to find files that are similar. "
      "These files could be candidates for merging, or suspects for copying, etc. "
      "What you do with them is your business :)")

  parser.add_argument("-t", "--threshold", type=float, default=0.95, 
      help="only show file pairs whose similarity is greater than the threshold [default = %(default).2f]")

  parser.add_argument("-a", "--accuracy", type=int, choices=[0, 1, 2], default=1, 
      help="accuracy level of comparisons. '2' is quite slow. [default = %(default)i]")

  parser.add_argument('files', nargs='+', 
      help="list of files to analyze")
  
  args = parser.parse_args()

  compare_files(args.files, args.threshold, args.accuracy)

if __name__ == '__main__':
  main()
