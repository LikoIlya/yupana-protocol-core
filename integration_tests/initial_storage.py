import json
import glob
from os.path import dirname, join, basename
from pytezos.michelson.format import micheline_to_michelson
from pytezos import ContractInterface, pytezos


def load_use_lambdas():
    lambdas = {}
    lambda_paths = glob.glob("./integration_tests/compiled/lambdas/use/*.json")
    for filepath in lambda_paths:
        lambda_string = open(filepath, 'r').read()
        micheline = json.loads(lambda_string)

        lambda_bytes = micheline["args"][0]["args"][0]["args"][0]["args"][0]["args"][0]

        michelson_code = micheline_to_michelson(lambda_bytes)

        filename = basename(filepath)
        index = filename.split("-")[0]

        lambdas[int(index)] = bytes.fromhex(lambda_bytes["bytes"])

        # res = dex.setUseAction(func=lambda_bytes["bytes"], index=int(index)).interpret(sender="KT18amZmM5W7qDWVt2pH6uj7sCEd3kbzLrHT")
        # print(res.storage)
        # exit(0)

        # left here in case it is necessary to do the same by entrypoint
        # dex.setUseFunction(michelson_code, int(index)).interpret()

    return lambdas

def load_token_lambdas():
    lambdas = {}
    lambda_paths = glob.glob("./integration_tests/compiled/lambdas/token/*.json")
    for filepath in lambda_paths:
        lambda_string = open(filepath, 'r').read()
        micheline = json.loads(lambda_string)

        lambda_bytes = micheline["args"][0]["args"][0]["args"][0]["args"][0]["args"][0]

        michelson_code = micheline_to_michelson(lambda_bytes)

        filename = basename(filepath)
        index = filename.split("-")[0]

        lambdas[int(index)] = bytes.fromhex(lambda_bytes["bytes"])

    return lambdas

use_lambdas = load_use_lambdas()
token_lambdas = load_token_lambdas()

initial_full_storage = {
    'useLambdas': use_lambdas,
    'tokenLambdas': token_lambdas,
    'storage': None
}