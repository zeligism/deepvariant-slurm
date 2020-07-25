# DeepVariant-Slurm

*\[Disclaimer: The pipelines are not 100% tested and\or guaranteed to be complete. Some DeepVariant parameters are hard-coded. All `sbatch` parameters are hard-coded as header comments. This is meant to be more of a template than a complete program.\]*

First of all, you should have a Singularity image of your favorite version of DeepVariant in order to run these pipelines.
You can see in the test script that I'm referencing an image called `deepvariant-0.9.0.simg`. Also, I'm using test data from a folder called "quickstart-testdata". Both are provided by Google and can be found here: https://console.cloud.google.com/storage/browser/deepvariant. You might find some other useful stuff in there as well.

Once you have everything ready, you can run the tests simply by just running the command `./run-deepvariant-calling-test` or any other script with the prefix `run`. Or you can directly run the pipelines with `./deepvariant-calling --arg1 value1 --arg2 value2` and `./deepvariant-training --args values --randomflag`. Some arguments are required, so make sure to inspect the scripts first, and make sure the scripts are executable using `chmod u+x <script>`, add `sudo` if needed.
