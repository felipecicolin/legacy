# frozen_string_literal: true

require "rails_helper"

# O que este spec defende é a instalação do Action Text: que o campo fecha o
# ciclo (salva, recarrega, renderiza) e que as duas podas do
# config/initializers/action_text.rb continuam valendo.
#
# Toda asserção de política olha a SAÍDA RENDERIZADA, nunca a coluna. O Action
# Text sanitiza na renderização, não na escrita: a coluna guarda o que chegou, e
# um teste apontado para ela reprovaria por um comportamento que é o esperado.
#
# O modelo é o `RichTextProbe`, de spec/support/ — não há domínio ainda.
RSpec.describe ActionText::RichText do
  let(:body) { "<div>Vistoria concluída</div>" }
  let(:probe) { RichTextProbe.create!(body: body) }

  describe "ida e volta ao banco" do
    it "recarrega o texto salvo" do
      expect(RichTextProbe.find(probe.id).body.to_plain_text).to eq("Vistoria concluída")
    end

    it "renderiza dentro do layout de conteúdo" do
      expect(probe.body.to_s).to include('<div class="trix-content">')
    end
  end

  describe "sanitização" do
    let(:body) { "<div>Vistoria</div><script>alert(1)</script>" }

    it "guarda na coluna o corpo como chegou" do
      expect(probe.reload.body.body.to_html).to include("<script>")
    end

    it "não deixa o script chegar à renderização" do
      expect(probe.body.to_s).not_to include("alert(1)")
    end
  end

  describe "anexo embutido" do
    let(:body) { %(<div>Obra</div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>) }
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("imagem"), filename: "planta.png",
                                             content_type: "image/png")
    end

    # Prova que o anexo REALMENTE estava no corpo — sem isto, os dois exemplos
    # seguintes passariam com um corpo vazio.
    it "reconhece o anexo no corpo salvo" do
      expect(probe.reload.body.embeds_blobs).to include(blob)
    end

    it "não renderiza o elemento de anexo" do
      expect(probe.body.to_s).not_to include("action-text-attachment")
    end

    it "não expõe a URL do blob" do
      expect(probe.body.to_s).not_to include("/rails/active_storage/")
    end
  end

  describe "listagem" do
    let(:body) { %(<action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>) }
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("imagem"), filename: "planta.png",
                                             content_type: "image/png")
    end

    before { 20.times { RichTextProbe.create!(body: body) } }

    it "mantém a contagem de queries constante com o preload" do
      expect(count_queries { touch_embeds(RichTextProbe.with_rich_text_body_and_embeds.limit(20)) })
        .to eq(count_queries { touch_embeds(RichTextProbe.with_rich_text_body_and_embeds.limit(5)) })
    end

    # O contraponto: sem o preload a mesma listagem cresce. Sem este exemplo o
    # anterior passaria mesmo que o escopo não fizesse nada.
    it "cresce com a listagem quando o preload não é usado" do
      expect(count_queries { touch_embeds(RichTextProbe.limit(20)) })
        .to be > count_queries { touch_embeds(RichTextProbe.limit(5)) }
    end

    def touch_embeds(scope)
      scope.each { |record| record.body.embeds.map(&:blob) }
    end
  end
end
