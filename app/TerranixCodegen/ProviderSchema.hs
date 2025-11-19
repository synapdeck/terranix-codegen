module TerranixCodegen.ProviderSchema (
  module TerranixCodegen.ProviderSchema.Types,
  module TerranixCodegen.ProviderSchema.CtyType,
  module TerranixCodegen.ProviderSchema.Attribute,
  module TerranixCodegen.ProviderSchema.Block,
  module TerranixCodegen.ProviderSchema.Schema,
  module TerranixCodegen.ProviderSchema.Identity,
  module TerranixCodegen.ProviderSchema.Function,
  module TerranixCodegen.ProviderSchema.Provider,
  parseProviderSchemas,
) where

import Data.Aeson (eitherDecode)
import Data.ByteString.Lazy.Char8 qualified as BL

import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Block
import TerranixCodegen.ProviderSchema.CtyType
import TerranixCodegen.ProviderSchema.Function
import TerranixCodegen.ProviderSchema.Identity
import TerranixCodegen.ProviderSchema.Provider
import TerranixCodegen.ProviderSchema.Schema
import TerranixCodegen.ProviderSchema.Types

parseProviderSchemas :: BL.ByteString -> Either String ProviderSchemas
parseProviderSchemas = eitherDecode
