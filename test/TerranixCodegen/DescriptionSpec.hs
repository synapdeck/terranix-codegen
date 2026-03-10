module TerranixCodegen.DescriptionSpec (spec) where

import Data.Text qualified as T
import Nix.TH (nix)
import Test.Hspec

import TerranixCodegen.Description
import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Block
import TerranixCodegen.ProviderSchema.Types (SchemaDescriptionKind (..))
import TestUtils (shouldMapTo)

emptyAttr :: SchemaAttribute
emptyAttr =
  SchemaAttribute
    { attributeType = Nothing
    , attributeNestedType = Nothing
    , attributeDescription = Nothing
    , attributeDescriptionKind = Nothing
    , attributeDeprecated = Nothing
    , attributeRequired = Nothing
    , attributeOptional = Nothing
    , attributeComputed = Nothing
    , attributeSensitive = Nothing
    , attributeWriteOnly = Nothing
    }

emptyBlock :: SchemaBlock
emptyBlock =
  SchemaBlock
    { blockAttributes = Nothing
    , blockNestedBlocks = Nothing
    , blockDescription = Nothing
    , blockDescriptionKind = Nothing
    , blockDeprecated = Nothing
    }

spec :: Spec
spec = do
  describe "fromAttribute" $ do
    it "extracts plain description" $ do
      let attr = emptyAttr {attributeDescription = Just "hello"}
      let Just desc = fromAttribute attr
      descriptionText desc `shouldBe` "hello"
      descriptionKind desc `shouldBe` Plain

    it "extracts markdown description" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "hello"
              , attributeDescriptionKind = Just Markdown
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldBe` "hello"
      descriptionKind desc `shouldBe` Markdown

    it "defaults to Plain when kind not specified" $ do
      let attr = emptyAttr {attributeDescription = Just "hello"}
      let Just desc = fromAttribute attr
      descriptionKind desc `shouldBe` Plain

    it "returns Nothing when no description or metadata" $ do
      fromAttribute emptyAttr `shouldBe` Nothing

    it "enriches with deprecation note" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Old field"
              , attributeDeprecated = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

    it "enriches with sensitivity warning" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Secret"
              , attributeSensitive = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "WARNING"

    it "enriches with write-only note" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Token"
              , attributeWriteOnly = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "write-only"

    it "enriches with computed note for computed-only attributes" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "ID"
              , attributeComputed = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "computed by the provider"

    it "does not add computed note for optional+computed attributes" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "IP"
              , attributeOptional = Just True
              , attributeComputed = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldBe` "IP"

    it "preserves markdown kind with metadata enrichment" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Old field"
              , attributeDescriptionKind = Just Markdown
              , attributeDeprecated = Just True
              }
      let Just desc = fromAttribute attr
      descriptionKind desc `shouldBe` Markdown

    it "creates description from metadata alone" $ do
      let attr = emptyAttr {attributeDeprecated = Just True}
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

  describe "fromBlock" $ do
    it "extracts plain block description" $ do
      let block = emptyBlock {blockDescription = Just "A block"}
      let Just desc = fromBlock block
      descriptionText desc `shouldBe` "A block"
      descriptionKind desc `shouldBe` Plain

    it "extracts markdown block description" $ do
      let block =
            emptyBlock
              { blockDescription = Just "A block"
              , blockDescriptionKind = Just Markdown
              }
      let Just desc = fromBlock block
      descriptionKind desc `shouldBe` Markdown

    it "returns Nothing for empty block" $ do
      fromBlock emptyBlock `shouldBe` Nothing

    it "enriches with deprecation note" $ do
      let block =
            emptyBlock
              { blockDescription = Just "Old block"
              , blockDeprecated = Just True
              }
      let Just desc = fromBlock block
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

    it "creates description from deprecated flag alone" $ do
      let block = emptyBlock {blockDeprecated = Just True}
      let Just desc = fromBlock block
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

  describe "toNExpr" $ do
    it "renders plain single-line as regular string" $ do
      toNExpr (fromText "hello" Plain) `shouldMapTo` [nix| "hello" |]

    it "renders markdown single-line with lib.mdDoc" $ do
      toNExpr (fromText "hello" Markdown) `shouldMapTo` [nix| lib.mdDoc "hello" |]
