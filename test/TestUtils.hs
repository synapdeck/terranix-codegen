module TestUtils (
  shouldMapTo,
) where

import Nix.Expr.Types (NExpr, stripPositionInfo)
import Test.Hspec

-- | Custom comparison that strips position info before comparing NExpr values
infix 1 `shouldMapTo`

shouldMapTo :: NExpr -> NExpr -> Expectation
shouldMapTo actual expected = stripPositionInfo actual `shouldBe` stripPositionInfo expected
