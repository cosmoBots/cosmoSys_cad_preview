# frozen_string_literal: true

get 'cosmosys/cad_preview/:id', to: 'cosmosys_cad_embeds#show', id: /\d+/
get 'cosmosys/cad_preview/:id/view', to: 'cosmosys_cad_embeds#view', id: /\d+/
put 'cosmosys/cad_preview/:id/view', to: 'cosmosys_cad_embeds#save_view', id: /\d+/
