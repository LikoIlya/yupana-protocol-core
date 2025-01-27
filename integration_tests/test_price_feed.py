from unittest import TestCase

from helpers import *
import copy

from pprint import pprint

from pytezos import ContractInterface, pytezos, MichelsonRuntimeError
from pytezos.context.mixin import ExecutionContext
from initial_storage import use_lambdas

token_a_address = "KT18amZmM5W7qDWVt2pH6uj7sCEd3kbzLrHT"
token_b_address = "KT1AxaBxkFLCUi3f8rdDAAxBKHfzY8LfKDRA"
token_c_address = "KT1XXAavg3tTj12W1ADvd3EEnm1pu6XTmiEF"
token_a = {"fA12": token_a_address}
token_b = {"fA12" : token_b_address}
token_c = {"fA12" : token_c_address}

oracle = "KT1LzyPS8rN375tC31WPAVHaQ4HyBvTSLwBu"
price_feed = "KT1Qf46j2x37sAN4t2MKRQRVt9gc4FZ5duMs"

one_percent_per_second = int(0.01 * PRECISION) #  interest rate

class PriceFeedTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.maxDiff = None

        code = open("./integration_tests/compiled/priceFeed.tz", 'r').read()
        cls.ct = ContractInterface.from_michelson(code)

        storage = cls.ct.storage.dummy()
        storage["admin"] = admin
        storage["oracle"] = oracle
        cls.storage = storage

    def test_price_feed_decimals(self):
        chain = LocalChain(storage=self.storage)

        chain.execute(self.ct.updatePair(3, "BTC-USD", 1_0000_0000), sender=admin)

        res = chain.execute(self.ct.receivePrice("BTC-USD", 0, 45_252_000_000), sender=oracle)
        
        op = res.operations[0]["parameters"]
        price = op["value"]["args"][1]["int"]
        price = int(price)

        one_btc = 1e8
        usd_precision = 1e6
        protocol_precision = 1e18

        self.assertEqual(int(price / protocol_precision * one_btc / usd_precision), 45_252)
