# frozen_string_literal: true

require "rails_helper"

# O que este spec defende: a moldura reserva o retângulo ANTES de a imagem
# existir. Sem isso a imagem chega, o container cresce e tudo abaixo dela
# salta — o layout shift que só aparece com a rede lenta de quem está na obra.
#
# E ele pergunta ao navegador que proporção cada utility resolveu, pelo mesmo
# motivo do spec dos tokens: `aspect-wide` que deixe de ser gerada não levanta
# erro em lugar nenhum. A regra continua na folha, o valor sai `auto`, e o
# enquadramento morre em silêncio.
RSpec.describe "Moldura de imagem" do
  let(:ratios) { { "playground" => 16.0 / 9, "four_by_three" => 4.0 / 3, "square" => 1.0 } }

  def visit_preview(example)
    visit "/rails/view_components/image_frame_component/#{example}"
  end

  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  def frame_box
    page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector("figure > div")
        const box = frame.getBoundingClientRect()
        return { width: box.width, height: box.height, ratio: getComputedStyle(frame).aspectRatio }
      })()
    JS
  end

  it "resolve uma proporção de verdade para cada enquadramento" do
    aggregate_failures do
      ratios.each_key do |example|
        visit_preview(example)

        expect(frame_box["ratio"]).not_to eq("auto"),
                                          "aspect-* saiu como auto em #{example}: a utility não foi " \
                                          "gerada — token removido ou renomeado"
      end
    end
  end

  it "reserva exatamente a altura que a proporção pede" do
    aggregate_failures do
      ratios.each do |example, ratio|
        visit_preview(example)
        box = frame_box

        expect(box["height"]).to be_within(1).of(box["width"] / ratio)
      end
    end
  end

  # A prova de que a altura não vem da imagem: o quadro vazio mede o mesmo que
  # o quadro que tem foto. Se a proporção não estivesse reservada, o vazio
  # colapsaria para zero.
  it "reserva a mesma altura com e sem anexo" do
    visit_preview("playground")
    with_photo = frame_box["height"]
    visit_preview("without_attachment")

    expect(frame_box["height"]).to eq(with_photo)
  end

  it "não mexe no layout quando a imagem termina de carregar" do
    visit_preview("playground")
    before_load = frame_box

    expect(await_image).to be(true)
    expect(frame_box).to eq(before_load)
  end

  # O ícone quebrado do navegador não passa por token nenhum e não fala
  # português. O quadro de apoio já está atrás da imagem, no mesmo retângulo:
  # esconder a imagem revela um estado neutro sem mover nada.
  it "cai num estado neutro quando a imagem não carrega" do
    visit_preview("playground")
    # O `srcset` precisa sair junto: com ele no lugar o navegador ignora o
    # `src` e a imagem continua carregando pela variante que já funcionava.
    page.execute_script(<<~JS)
      const image = document.querySelector("figure img")
      image.srcset = ""
      image.src = "/variante-que-nao-existe.png"
    JS

    expect(page).to have_css("figure img", visible: :hidden)
    expect(page).to have_css("figure div[data-image-frame-component-target='fallback']:not([aria-hidden])")
  end

  # A moldura é `w-full`, então nada aqui deveria estourar a viewport — mas é
  # exatamente esse tipo de regressão que passa despercebida no desktop e só
  # aparece no telefone de quem está na obra.
  it "cabe na largura da tela em 375, 768 e 1440px" do
    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit_preview("playground")

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  # A variante é processada sob demanda: a primeira visita dispara a libvips
  # pelo controller de representação, então esperar o evento é esperar o
  # trabalho de verdade, não um round trip de cache.
  def await_image
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const image = document.querySelector("figure img")
      if (image.complete) return done(image.naturalWidth > 0)
      image.addEventListener("load", () => done(true))
      image.addEventListener("error", () => done(false))
    JS
  end
end
