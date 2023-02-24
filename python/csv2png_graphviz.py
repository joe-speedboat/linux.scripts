#!/usr/bin/python3

##############################################################################################################
# DESC: create graphviz tree structrue image from csv
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt
#
# SETUP: dnf install graphviz graphviz-python3 python3-pydot
#
# CSV SAMPLE:
# router66
# router66,switch0101
# router66,switch0101,switch0104

import os
import sys
import csv
from jinja2 import Template

TEMPLATE = """
digraph G {
  rankdir=LR;
  node [shape=box];
  {% for line in lines %}
  {{ line }};
  {% endfor %}
}
"""

# check if the input file exists
input_file = sys.argv[1]
if not os.path.isfile(input_file):
    print(f"Input file '{input_file}' does not exist.")
    sys.exit(1)

# construct the output filename
output_dir = os.path.dirname(input_file)
output_base = os.path.splitext(os.path.basename(input_file))[0]
output_file = os.path.join(output_dir, f"{output_base}.png")

# read the CSV file
with open(input_file, 'r') as f:
    reader = csv.reader(f)
    lines = []

    # convert each line of the CSV file to a Graphviz statement
    for row in reader:
        line = ' -> '.join(row)
        lines.append(line)

# load the template string
template = Template(TEMPLATE)

# render the template with the lines from the CSV file
output = template.render(lines=lines)

# use Graphviz to convert the DOT data to a PNG image
os.system(f"echo \"{output}\" | dot -Tpng -o {output_file}")

print(f"Graphviz image saved to '{output_file}'.")
