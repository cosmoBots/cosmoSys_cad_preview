# frozen_string_literal: true

get 'cosmosys/cad_preview/:id', to: 'cosmosys_cad_embeds#show', id: /\d+/
