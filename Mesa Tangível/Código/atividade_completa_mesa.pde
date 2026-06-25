//bibliotecas boofCV para reconhecer os QR codes
import processing.video.*;
import boofcv.processing.*;
import java.util.*;
import boofcv.alg.fiducial.qrcode.QrCode;
import georegression.struct.point.Point2D_F64;
import processing.sound.*;

Capture cam;
SimpleQrCode detector;
Table tabelaLog;

Cena[] cenas;
int cenaAtual = 0;
int tempoInicioCena;
String ultimoCodigo = "";
boolean travaDeRemocao = false;

// Variáveis para ajuste de tela
float offX, offY; // Margens (barras pretas)
float destW, destH; // Largura e altura final da imagem na tela
final float LARGURA_ORIGINAL = 600.0;
final float ALTURA_ORIGINAL = 400.0;

class Cena {
  PImage imagem;
  String nome;
  String nomeArquivo;   // guarda o nome da imagem para carregar depois
  String nomeAudio;     // guarda o nome do áudio para carregar depois
  ArrayList<Area> areasInterativas;
  int tempoTransicao;
  boolean usaTempo;
  SoundFile som;
  boolean somJaDisparou;
  
  Cena(String nomeArquivo, String nomeCena) {
    this.nomeArquivo = nomeArquivo; // só guarda o nome, não carrega ainda
    this.imagem = null;
    this.nome = nomeCena;
    this.areasInterativas = new ArrayList<Area>();
    this.tempoTransicao = 0;
    this.usaTempo = false;
    this.som = null;
    this.nomeAudio = null;
    this.somJaDisparou = false;
  }
  
  // Carrega imagem e som na memória (chamado só ao entrar na cena)
  void carregar(PApplet p) {
    if (imagem == null && nomeArquivo != null) {
      imagem = loadImage(nomeArquivo);
    }
    if (som == null && nomeAudio != null) {
      try {
        som = new SoundFile(p, nomeAudio);
      } catch (Exception e) {
        println("Erro ao carregar som: " + nomeAudio);
      }
    }
  }
  
  // Liberta imagem e som da memória (chamado ao sair da cena)
  void descarregar() {
    imagem = null;
    if (som != null) {
      som.stop();
      som = null;
    }
    somJaDisparou = false;
  }
  
  void adicionarArea(Area area) {
    areasInterativas.add(area);
  }
  
  void definirTransicaoTempo(int segundos) {
    this.tempoTransicao = segundos;
    this.usaTempo = true;
  }
  
  // Agora só guarda o nome do áudio — o som é carregado em carregar()
  void definirAudio(PApplet p, String nomeAudio) {
    this.nomeAudio = nomeAudio;
    // Se a cena já está ativa (ex: cenas de erro configuradas dinamicamente),
    // carrega o som imediatamente
    if (som != null) {
      som.stop();
      som = null;
    }
    try {
      som = new SoundFile(p, nomeAudio);
    } catch (Exception e) {
      println("Erro ao carregar som: " + nomeAudio);
    }
  }

  void gerenciarAudio(int momentoInicioCena) {
    if (this.som != null && !this.somJaDisparou) {
      if (millis() - momentoInicioCena > 2500) {
        this.som.play();
        this.somJaDisparou = true;
      }
    }
  }

  //reseta o audio quando sai da cena
  void resetarAudio() {
    if (this.som != null) {
      this.som.stop();
    }
    this.somJaDisparou = false;
  }
}

class Area {
  String nome;
  float x, y, w, h;
  int cenaDestino;
  
  Area(String nome, float x, float y, float w, float h, int cenaDestino) {
    this.nome = nome;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.cenaDestino = cenaDestino;
  }
  
  // Modificado para considerar a escala da tela atual em relação ao projeto original (600x400)
  boolean contem(float px, float py) {
    // Calcula a posição real na tela baseada no ajuste
    float realX = offX + (x / LARGURA_ORIGINAL) * destW;
    float realY = offY + (y / ALTURA_ORIGINAL) * destH;
    float realW = (w / LARGURA_ORIGINAL) * destW;
    float realH = (h / ALTURA_ORIGINAL) * destH;
    
    return px >= realX && px <= realX + realW && py >= realY && py <= realY + realH;
  }
  
  void desenhar() {
    float realX = offX + (x / LARGURA_ORIGINAL) * destW;
    float realY = offY + (y / ALTURA_ORIGINAL) * destH;
    float realW = (w / LARGURA_ORIGINAL) * destW;
    float realH = (h / ALTURA_ORIGINAL) * destH;
    
    noFill();
    stroke(0, 255, 0);
    strokeWeight(2);
    rect(realX, realY, realW, realH);
    fill(0, 255, 0);
    textSize(15);
    text(nome, realX + 5, realY + 15);
  }
}

void setup() {
  fullScreen();
  
  tabelaLog = new Table();
  tabelaLog.addColumn("Hora");
  tabelaLog.addColumn("Cena_ID");
  tabelaLog.addColumn("Tipo_Evento"); // mudança de cena, tentativa, erro, acerto
  tabelaLog.addColumn("Detalhe");     // qual qr code foi lido
  registrarLog("SISTEMA", "Jogo Iniciado");
  
  calcularEscalaTela(); // Calcula as dimensões assim que inicia

  //inicializa câmera
  inicializaCamera(640, 480);

  //inicializa o detector de QR codes
  detector = Boof.detectQR();

  //inicializa o sistema de cenas (só guarda os nomes, não carrega assets)
  inicializarCenas();
  
  // Carrega apenas a primeira cena na memória
  cenas[0].carregar(this);
  
  tempoInicioCena = millis();
}

void inicializarCenas() {
  
  // em adicionar area os campos são("NOME", x, y, largura, altura, cena destino)
  //Aqui você vai definir quantas cenas precisa
  cenas = new Cena[130];
  
  //INICIO
  cenas[0] = new Cena("inicio.png", "Inicio");
  
  //INSTRUCOES
  cenas[1] = new Cena("instrucoes.png", "Instrucoes");
  cenas[1].definirAudio(this, "audio_introducao.mp3");
  cenas[1].definirTransicaoTempo(65);
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[2] = new Cena("escolha_opcao.png", "Escolher uma opcao");
  cenas[2].definirAudio(this, "audio_escolha_opcao.mp3");
  
  //CENAS DAS CURIOSIDADES 1
  cenas[3] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[3].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[4] = new Cena("sol.png", "Sol");
  cenas[4].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[4].definirTransicaoTempo(44);
  cenas[5] = new Cena("mercurio.png", "Mercurio");
  cenas[5].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[5].definirTransicaoTempo(51);
  cenas[6] = new Cena("venus.png", "Venus");
  cenas[6].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[6].definirTransicaoTempo(75);
  cenas[7] = new Cena("terra.png", "Terra");
  cenas[7].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[7].definirTransicaoTempo(55);
  cenas[8] = new Cena("marte.png", "Marte");
  cenas[8].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[8].definirTransicaoTempo(65);
  cenas[9] = new Cena("jupiter.png", "Jupiter");
  cenas[9].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[9].definirTransicaoTempo(50);
  cenas[10] = new Cena("saturno.png", "Saturno");
  cenas[10].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[10].definirTransicaoTempo(60);
  cenas[11] = new Cena("urano.png", "Urano");
  cenas[11].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[11].definirTransicaoTempo(44);
  cenas[12] = new Cena("netuno.png", "Netuno");
  cenas[12].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[12].definirTransicaoTempo(60);
  
  //CENA HORA DO QUIZ
  cenas[13] = new Cena("hora_do_quiz.png", "Hora do quiz");
  cenas[13].definirAudio(this, "audio_hora_do_quiz.mp3");
  cenas[13].definirTransicaoTempo(7);
  
  //PERGUNTA 1
  cenas[14] = new Cena("pergunta_um.png", "Pergunta 1");
  cenas[14].definirAudio(this, "audio_pergunta_um.mp3");
  cenas[15] = new Cena("cena_acertou.png", "Acertou");
  cenas[15].definirAudio(this, "acertou_marte.mp3");
  cenas[15].definirTransicaoTempo(13);
  cenas[16] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[17] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[17].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 2
  cenas[18] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[18].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[19] = new Cena("sol.png", "Sol");
  cenas[19].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[19].definirTransicaoTempo(44);
  cenas[20] = new Cena("mercurio.png", "Mercurio");
  cenas[20].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[20].definirTransicaoTempo(51);
  cenas[21] = new Cena("venus.png", "Venus");
  cenas[21].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[21].definirTransicaoTempo(75);
  cenas[22] = new Cena("terra.png", "Terra");
  cenas[22].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[22].definirTransicaoTempo(55);
  cenas[23] = new Cena("marte.png", "Marte");
  cenas[23].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[23].definirTransicaoTempo(65);
  cenas[24] = new Cena("jupiter.png", "Jupiter");
  cenas[24].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[24].definirTransicaoTempo(50);
  cenas[25] = new Cena("saturno.png", "Saturno");
  cenas[25].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[25].definirTransicaoTempo(60);
  cenas[26] = new Cena("urano.png", "Urano");
  cenas[26].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[26].definirTransicaoTempo(44);
  cenas[27] = new Cena("netuno.png", "Netuno");
  cenas[27].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[27].definirTransicaoTempo(60);
  
  //PERGUNTA 2
  cenas[28] = new Cena("pergunta_dois.png", "Pergunta 2");
  cenas[28].definirAudio(this, "audio_pergunta_dois.mp3");
  cenas[29] = new Cena("cena_acertou.png", "Acertou");
  cenas[29].definirAudio(this, "acertou_saturno.mp3");
  cenas[29].definirTransicaoTempo(13);
  cenas[30] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[31] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[31].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 3
  cenas[32] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[32].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[33] = new Cena("sol.png", "Sol");
  cenas[33].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[33].definirTransicaoTempo(44);
  cenas[34] = new Cena("mercurio.png", "Mercurio");
  cenas[34].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[34].definirTransicaoTempo(51);
  cenas[35] = new Cena("venus.png", "Venus");
  cenas[35].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[35].definirTransicaoTempo(75);
  cenas[36] = new Cena("terra.png", "Terra");
  cenas[36].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[36].definirTransicaoTempo(55);
  cenas[37] = new Cena("marte.png", "Marte");
  cenas[37].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[37].definirTransicaoTempo(65);
  cenas[38] = new Cena("jupiter.png", "Jupiter");
  cenas[38].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[38].definirTransicaoTempo(50);
  cenas[39] = new Cena("saturno.png", "Saturno");
  cenas[39].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[39].definirTransicaoTempo(60);
  cenas[40] = new Cena("urano.png", "Urano");
  cenas[40].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[40].definirTransicaoTempo(44);
  cenas[41] = new Cena("netuno.png", "Netuno");
  cenas[41].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[41].definirTransicaoTempo(60);
  
  //PERGUNTA 3
  cenas[42] = new Cena("pergunta_tres.png", "Pergunta 3");
  cenas[42].definirAudio(this, "audio_pergunta_tres.mp3");
  cenas[43] = new Cena("cena_acertou.png", "Acertou");
  cenas[43].definirAudio(this, "acertou_venus.mp3");
  cenas[43].definirTransicaoTempo(12);
  cenas[44] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[45] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[45].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 4
  cenas[46] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[46].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[47] = new Cena("sol.png", "Sol");
  cenas[47].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[47].definirTransicaoTempo(44);
  cenas[48] = new Cena("mercurio.png", "Mercurio");
  cenas[48].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[48].definirTransicaoTempo(51);
  cenas[49] = new Cena("venus.png", "Venus");
  cenas[49].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[49].definirTransicaoTempo(75);
  cenas[50] = new Cena("terra.png", "Terra");
  cenas[50].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[50].definirTransicaoTempo(55);
  cenas[51] = new Cena("marte.png", "Marte");
  cenas[51].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[51].definirTransicaoTempo(65);
  cenas[52] = new Cena("jupiter.png", "Jupiter");
  cenas[52].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[52].definirTransicaoTempo(50);
  cenas[53] = new Cena("saturno.png", "Saturno");
  cenas[53].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[53].definirTransicaoTempo(60);
  cenas[54] = new Cena("urano.png", "Urano");
  cenas[54].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[54].definirTransicaoTempo(44);
  cenas[55] = new Cena("netuno.png", "Netuno");
  cenas[55].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[55].definirTransicaoTempo(60);
  
  //PERGUNTA 4
  cenas[56] = new Cena("pergunta_quatro.png", "Pergunta 4");
  cenas[56].definirAudio(this, "audio_pergunta_quatro.mp3");
  cenas[57] = new Cena("cena_acertou.png", "Acertou");
  cenas[57].definirAudio(this, "acertou_netuno.mp3");
  cenas[57].definirTransicaoTempo(14);
  cenas[58] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[59] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[59].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 5 
  cenas[60] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[60].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[61] = new Cena("sol.png", "Sol");
  cenas[61].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[61].definirTransicaoTempo(44);
  cenas[62] = new Cena("mercurio.png", "Mercurio");
  cenas[62].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[62].definirTransicaoTempo(51);
  cenas[63] = new Cena("venus.png", "Venus");
  cenas[63].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[63].definirTransicaoTempo(75);
  cenas[64] = new Cena("terra.png", "Terra");
  cenas[64].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[64].definirTransicaoTempo(55);
  cenas[65] = new Cena("marte.png", "Marte");
  cenas[65].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[65].definirTransicaoTempo(65);
  cenas[66] = new Cena("jupiter.png", "Jupiter");
  cenas[66].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[66].definirTransicaoTempo(50);
  cenas[67] = new Cena("saturno.png", "Saturno");
  cenas[67].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[67].definirTransicaoTempo(60);
  cenas[68] = new Cena("urano.png", "Urano");
  cenas[68].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[68].definirTransicaoTempo(44);
  cenas[69] = new Cena("netuno.png", "Netuno");
  cenas[69].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[69].definirTransicaoTempo(60);
  
  //PERGUNTA 5
  cenas[70] =  new Cena("pergunta_cinco.png", "Pergunta 5");
  cenas[70].definirAudio(this, "audio_pergunta_cinco.mp3");
  cenas[71] = new Cena("cena_acertou.png", "Acertou");
  cenas[71].definirAudio(this, "acertou_terra.mp3");
  cenas[71].definirTransicaoTempo(13);
  cenas[72] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[73] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[73].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 6
  cenas[74] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[74].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[75] = new Cena("sol.png", "Sol");
  cenas[75].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[75].definirTransicaoTempo(44);
  cenas[76] = new Cena("mercurio.png", "Mercurio");
  cenas[76].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[76].definirTransicaoTempo(51);
  cenas[77] = new Cena("venus.png", "Venus");
  cenas[77].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[77].definirTransicaoTempo(75);
  cenas[78] = new Cena("terra.png", "Terra");
  cenas[78].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[78].definirTransicaoTempo(55);
  cenas[79] = new Cena("marte.png", "Marte");
  cenas[79].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[79].definirTransicaoTempo(65);
  cenas[80] = new Cena("jupiter.png", "Jupiter");
  cenas[80].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[80].definirTransicaoTempo(50);
  cenas[81] = new Cena("saturno.png", "Saturno");
  cenas[81].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[81].definirTransicaoTempo(60);
  cenas[82] = new Cena("urano.png", "Urano");
  cenas[82].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[82].definirTransicaoTempo(44);
  cenas[83] = new Cena("netuno.png", "Netuno");
  cenas[83].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[83].definirTransicaoTempo(60);
  
  //PERGUNTA 6
  cenas[84] =  new Cena("pergunta_seis.png", "Pergunta 6");
  cenas[84].definirAudio(this, "audio_pergunta_seis.mp3");
  cenas[85] = new Cena("cena_acertou.png", "Acertou");
  cenas[85].definirAudio(this, "acertou_urano.mp3");
  cenas[85].definirTransicaoTempo(13);
  cenas[86] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[87] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[87].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 7
  cenas[88] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[88].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[89] = new Cena("sol.png", "Sol");
  cenas[89].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[89].definirTransicaoTempo(44);
  cenas[90] = new Cena("mercurio.png", "Mercurio");
  cenas[90].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[90].definirTransicaoTempo(51);
  cenas[91] = new Cena("venus.png", "Venus");
  cenas[91].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[91].definirTransicaoTempo(75);
  cenas[92] = new Cena("terra.png", "Terra");
  cenas[92].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[92].definirTransicaoTempo(55);
  cenas[93] = new Cena("marte.png", "Marte");
  cenas[93].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[93].definirTransicaoTempo(65);
  cenas[94] = new Cena("jupiter.png", "Jupiter");
  cenas[94].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[94].definirTransicaoTempo(50);
  cenas[95] = new Cena("saturno.png", "Saturno");
  cenas[95].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[95].definirTransicaoTempo(60);
  cenas[96] = new Cena("urano.png", "Urano");
  cenas[96].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[96].definirTransicaoTempo(44);
  cenas[97] = new Cena("netuno.png", "Netuno");
  cenas[97].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[97].definirTransicaoTempo(60);
  
  //PERGUNTA 7
  cenas[98] = new Cena("pergunta_sete.png", "Pergunta 7");
  cenas[98].definirAudio(this, "audio_pergunta_sete.mp3");
  cenas[99] = new Cena("cena_acertou.png", "Acertou");
  cenas[99].definirAudio(this, "acertou_mercurio.mp3");
  cenas[99].definirTransicaoTempo(12);
  cenas[100] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[101] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[101].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 8
  cenas[102] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[102].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[103] = new Cena("sol.png", "Sol");
  cenas[103].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[103].definirTransicaoTempo(44);
  cenas[104] = new Cena("mercurio.png", "Mercurio");
  cenas[104].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[104].definirTransicaoTempo(51);
  cenas[105] = new Cena("venus.png", "Venus");
  cenas[105].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[105].definirTransicaoTempo(75);
  cenas[106] = new Cena("terra.png", "Terra");
  cenas[106].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[106].definirTransicaoTempo(55);
  cenas[107] = new Cena("marte.png", "Marte");
  cenas[107].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[107].definirTransicaoTempo(65);
  cenas[108] = new Cena("jupiter.png", "Jupiter");
  cenas[108].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[108].definirTransicaoTempo(50);
  cenas[109] = new Cena("saturno.png", "Saturno");
  cenas[109].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[109].definirTransicaoTempo(60);
  cenas[110] = new Cena("urano.png", "Urano");
  cenas[110].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[110].definirTransicaoTempo(44);
  cenas[111] = new Cena("netuno.png", "Netuno");
  cenas[111].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[111].definirTransicaoTempo(60);
  
  //PERGUNTA 8
  cenas[112] = new Cena("pergunta_oito.png", "Pergunta 8");
  cenas[112].definirAudio(this, "audio_pergunta_oito.mp3");
  cenas[113] = new Cena("cena_acertou.png", "Acertou");
  cenas[113].definirAudio(this, "acertou_jupiter.mp3");
  cenas[113].definirTransicaoTempo(12);
  cenas[114] = new Cena("cena_errou.png", "Errou");
  
  //ESCOLHA QUIZ OU CURIOSIDADES
  cenas[115] = new Cena("proxima_questao.png", "Próxima Questão");
  cenas[115].definirAudio(this, "audio_escolha_opcao_dois.mp3");
  
  //CENAS DAS CURIOSIDADES 9
  cenas[116] = new Cena("objeto_sobre_a_mesa.png", "Fundo Curiosidades");
  cenas[116].definirAudio(this, "audio_escolheu_curiosidades.mp3");
  cenas[117] = new Cena("sol.png", "Sol");
  cenas[117].definirAudio(this, "audio_curiosidade_sol.mp3");
  cenas[117].definirTransicaoTempo(44);
  cenas[118] = new Cena("mercurio.png", "Mercurio");
  cenas[118].definirAudio(this, "audio_curiosidade_mercurio.mp3");
  cenas[118].definirTransicaoTempo(51);
  cenas[119] = new Cena("venus.png", "Venus");
  cenas[119].definirAudio(this, "audio_curiosidade_venus.mp3");
  cenas[119].definirTransicaoTempo(75);
  cenas[120] = new Cena("terra.png", "Terra");
  cenas[120].definirAudio(this, "audio_curiosidade_terra.mp3");
  cenas[120].definirTransicaoTempo(55);
  cenas[121] = new Cena("marte.png", "Marte");
  cenas[121].definirAudio(this, "audio_curiosidade_marte.mp3");
  cenas[121].definirTransicaoTempo(65);
  cenas[122] = new Cena("jupiter.png", "Jupiter");
  cenas[122].definirAudio(this, "audio_curiosidade_jupiter.mp3");
  cenas[122].definirTransicaoTempo(50);
  cenas[123] = new Cena("saturno.png", "Saturno");
  cenas[123].definirAudio(this, "audio_curiosidade_saturno.mp3");
  cenas[123].definirTransicaoTempo(60);
  cenas[124] = new Cena("urano.png", "Urano");
  cenas[124].definirAudio(this, "audio_curiosidade_urano.mp3");
  cenas[124].definirTransicaoTempo(44);
  cenas[125] = new Cena("netuno.png", "Netuno");
  cenas[125].definirAudio(this, "audio_curiosidade_netuno.mp3");
  cenas[125].definirTransicaoTempo(60);
  
  //PERGUNTA 9
  cenas[126] = new Cena("pergunta_nove.png", "Pergunta 9");
  cenas[126].definirAudio(this, "audio_pergunta_nove.mp3");
  cenas[127] = new Cena("cena_acertou.png", "Acertou");
  cenas[127].definirAudio(this, "acertou_sol.mp3");
  cenas[127].definirTransicaoTempo(13);
  cenas[128] = new Cena("cena_errou.png", "Errou");
  
  //FIM
  cenas[129] = new Cena("fim.png", "Fim");
  cenas[129].definirAudio(this, "audio_finalizacao.mp3");
  cenas[129].definirTransicaoTempo(46);
  
  // PARA CADA CENA, VOCÊ PODE:
  // - Adicionar áreas interativas: cenas[X].adicionarArea(new Area(...))
  // - Definir transição por tempo: cenas[X].definirTransicaoTempo(segundos)
}

void draw() {
  if (cam.available() == true) {
    cam.read();
  }

  //Desenha a cena atual
  desenharCenaAtual();
  
  //verifica se já passou 2,5 segundos e liga o audio
  if (cenas[cenaAtual] != null) {
    cenas[cenaAtual].gerenciarAudio(tempoInicioCena);
  }
  
  //Processa interações com QR codes
  processarInteracoes();
  
  //Verifica transições por tempo
  verificarTransicaoTempo();
  
  if (cenaAtual == 129) { 
  registrarLog("FIM", "Jogo concluído");
  salvarRelatorioFinal(); // <--- ISSO GERA O ARQUIVO
  }
}

void desenharCenaAtual() {
  background(0); // cria as barras pretas
  
  if (cenas[cenaAtual] != null && cenas[cenaAtual].imagem != null) {
    image(cenas[cenaAtual].imagem, offX, offY, destW, destH);
  }
}

void processarInteracoes() {
  List<QrCode> encontrados = detector.detect(cam);

  // SE TIVER QR CODE NA TELA
  if (encontrados.size() > 0) {
    
    // SE A TRAVA ESTIVER ATIVA, NÃO FAZ NADA (Obriga a tirar o QR CODE DA MESA)
    if (travaDeRemocao == true) {
      return; 
    }

    String mensagem = encontrados.get(0).message;
    
    // Se o código é novo (ou acabou de ser destravado)
    if (!mensagem.equals(ultimoCodigo)) {
      ultimoCodigo = mensagem;
      println("QR Processado: " + mensagem);
      
      processarQRCodeEspecifico(mensagem);
      
      // DEPOIS DE PROCESSAR, ATIVA A TRAVA IMEDIATAMENTE
      travaDeRemocao = true;
    }
  } 
  // SE NÃO TIVER NADA NA TELA
  else {
    travaDeRemocao = false; // Destrava o sistema
    ultimoCodigo = "";      // Limpa a memória
  }
}

void processarQRCodeEspecifico(String mensagemQR) {
  println("QR Code específico detectado: " + mensagemQR);
  
  // Trava de segurança para não processar seletores nas perguntas
  if ((mensagemQR.equalsIgnoreCase("seletor") || mensagemQR.equalsIgnoreCase("SeletorQuiz")) && 
      (cenaAtual == 14 || cenaAtual == 28 || cenaAtual == 42 || cenaAtual == 56 || 
       cenaAtual == 70 || cenaAtual == 84 || cenaAtual == 98 || cenaAtual == 112 || cenaAtual == 126)) {
       
    return;
  }
 
  else if (cenaAtual == 2){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      registrarLog("NAVEGACAO", "Foi para Curiosidades"); // LOG
      mudarCena(3);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        registrarLog("NAVEGACAO", "Foi para Quiz"); // LOG
        mudarCena(13);
      }
  }
  
  //SE ESTIVER NA CENA 3 (Fundo Curiosidades)
  else if (cenaAtual == 3) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(4); 
        break;
      case "mercurio": mudarCena(5);
        break;
      case "venus": mudarCena(6);
        break;
      case "terra": mudarCena(7);
        break;
      case "marte": mudarCena(8);
        break;
      case "jupiter": mudarCena(9);
        break;
      case "saturno": mudarCena(10);
        break;
      case "urano": mudarCena(11);
        break;
      case "netuno": mudarCena(12);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 1
  else if(cenaAtual == 14){
    switch(mensagemQR){
      case "marte": 
        registrarLog("ACERTO", "P1: Acertou (Marte)"); // LOG ACERTO
        mudarCena(15);
        break;
      default:
        registrarLog("ERRO", "P1: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[16].definirAudio(this, "errou_sol.mp3"); cenas[16].definirTransicaoTempo(15); break;
          case "mercurio": cenas[16].definirAudio(this, "errou_mercurio.mp3"); cenas[16].definirTransicaoTempo(36); break;
          case "venus": cenas[16].definirAudio(this, "errou_venus.mp3"); cenas[16].definirTransicaoTempo(33); break;
          case "terra": cenas[16].definirAudio(this, "errou_terra.mp3"); cenas[16].definirTransicaoTempo(28); break;
          case "jupiter": cenas[16].definirAudio(this, "errou_jupiter.mp3"); cenas[16].definirTransicaoTempo(35); break;
          case "saturno": cenas[16].definirAudio(this, "errou_saturno.mp3"); cenas[16].definirTransicaoTempo(25); break;
          case "urano": cenas[16].definirAudio(this, "errou_urano.mp3"); cenas[16].definirTransicaoTempo(22); break;
          case "netuno": cenas[16].definirAudio(this, "errou_netuno.mp3"); cenas[16].definirTransicaoTempo(21); break;
        }
        mudarCena(16);
        break;
    }
  }
  
  else if (cenaAtual == 17){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(18);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(28);
      }
  }
  
  //SE ESTIVER NA CENA 18 (Fundo Curiosidades)
  else if (cenaAtual == 18) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(19); 
        break;
      case "mercurio": mudarCena(20);
        break;
      case "venus": mudarCena(21);
        break;
      case "terra": mudarCena(22);
        break;
      case "marte": mudarCena(23);
        break;
      case "jupiter": mudarCena(24);
        break;
      case "saturno": mudarCena(25);
        break;
      case "urano": mudarCena(26);
        break;
      case "netuno": mudarCena(27);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 2
  else if(cenaAtual == 28){
    switch(mensagemQR){
      case "saturno": 
        registrarLog("ACERTO", "P2: Acertou (Saturno)"); // LOG ACERTO
        mudarCena(29);
        break;
      default:
        registrarLog("ERRO", "P2: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[30].definirAudio(this, "errou_sol.mp3"); cenas[30].definirTransicaoTempo(15); break;
          case "mercurio": cenas[30].definirAudio(this, "errou_mercurio.mp3"); cenas[30].definirTransicaoTempo(36); break;
          case "venus": cenas[30].definirAudio(this, "errou_venus.mp3"); cenas[30].definirTransicaoTempo(33); break;
          case "terra": cenas[30].definirAudio(this, "errou_terra.mp3"); cenas[30].definirTransicaoTempo(28); break;
          case "marte": cenas[30].definirAudio(this, "errou_marte.mp3"); cenas[30].definirTransicaoTempo(19); break;
          case "jupiter": cenas[30].definirAudio(this, "errou_jupiter.mp3"); cenas[30].definirTransicaoTempo(35); break;
          case "urano": cenas[30].definirAudio(this, "errou_urano.mp3"); cenas[30].definirTransicaoTempo(22); break;
          case "netuno": cenas[30].definirAudio(this, "errou_netuno.mp3"); cenas[30].definirTransicaoTempo(21); break;
        }
        mudarCena(30);
        break;
    }
  }
  
  else if (cenaAtual == 31){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(32);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(42);
      }
  }
  
  //SE ESTIVER NA CENA 32 (Fundo Curiosidades)
  else if (cenaAtual == 32) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(33); 
        break;
      case "mercurio": mudarCena(34);
        break;
      case "venus": mudarCena(35);
        break;
      case "terra": mudarCena(36);
        break;
      case "marte": mudarCena(37);
        break;
      case "jupiter": mudarCena(38);
        break;
      case "saturno": mudarCena(39);
        break;
      case "urano": mudarCena(40);
        break;
      case "netuno": mudarCena(41);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 3
  else if(cenaAtual == 42){
    switch(mensagemQR){
      case "venus": 
        registrarLog("ACERTO", "P3: Acertou (Venus)"); // LOG ACERTO
        mudarCena(43);
        break;
      default: 
        registrarLog("ERRO", "P3: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[44].definirAudio(this, "errou_sol.mp3"); cenas[44].definirTransicaoTempo(15); break;
          case "mercurio": cenas[44].definirAudio(this, "errou_mercurio.mp3"); cenas[44].definirTransicaoTempo(36); break;
          case "terra": cenas[44].definirAudio(this, "errou_terra.mp3"); cenas[44].definirTransicaoTempo(28); break;
          case "marte": cenas[44].definirAudio(this, "errou_marte.mp3"); cenas[44].definirTransicaoTempo(19); break;
          case "jupiter": cenas[44].definirAudio(this, "errou_jupiter.mp3"); cenas[44].definirTransicaoTempo(35); break;
          case "saturno": cenas[44].definirAudio(this, "errou_saturno.mp3"); cenas[44].definirTransicaoTempo(25); break;
          case "urano": cenas[44].definirAudio(this, "errou_urano.mp3"); cenas[44].definirTransicaoTempo(22); break;
          case "netuno": cenas[44].definirAudio(this, "errou_netuno.mp3"); cenas[44].definirTransicaoTempo(21); break;
        }
        mudarCena(44);
        break;
    }
  }
  
  else if (cenaAtual == 45){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(46);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(56);
      }
  }
  
  //SE ESTIVER NA CENA 46 (Fundo Curiosidades)
  else if (cenaAtual == 46) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(47); 
        break;
      case "mercurio": mudarCena(48);
        break;
      case "venus": mudarCena(49);
        break;
      case "terra": mudarCena(50);
        break;
      case "marte": mudarCena(51);
        break;
      case "jupiter": mudarCena(52);
        break;
      case "saturno": mudarCena(53);
        break;
      case "urano": mudarCena(54);
        break;
      case "netuno": mudarCena(55);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 4
  else if(cenaAtual == 56){
    switch(mensagemQR){
      case "netuno": 
        registrarLog("ACERTO", "P4: Acertou (Netuno)"); // LOG ACERTO
        mudarCena(57);
        break;
      default: 
        registrarLog("ERRO", "P4: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[58].definirAudio(this, "errou_sol.mp3"); cenas[58].definirTransicaoTempo(15); break;
          case "mercurio": cenas[58].definirAudio(this, "errou_mercurio.mp3"); cenas[58].definirTransicaoTempo(36); break;
          case "venus": cenas[58].definirAudio(this, "errou_venus.mp3"); cenas[58].definirTransicaoTempo(33); break;
          case "terra": cenas[58].definirAudio(this, "errou_terra.mp3"); cenas[58].definirTransicaoTempo(28); break;
          case "marte": cenas[58].definirAudio(this, "errou_marte.mp3"); cenas[58].definirTransicaoTempo(19); break;
          case "jupiter": cenas[58].definirAudio(this, "errou_jupiter.mp3"); cenas[58].definirTransicaoTempo(35); break;
          case "saturno": cenas[58].definirAudio(this, "errou_saturno.mp3"); cenas[58].definirTransicaoTempo(25); break;
          case "urano": cenas[58].definirAudio(this, "errou_urano.mp3"); cenas[58].definirTransicaoTempo(22); break;
        }
        mudarCena(58);
        break;
    }
  }
  
  else if (cenaAtual == 59){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(60);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(70);
      }
  }
  
  //SE ESTIVER NA CENA 60 (Fundo Curiosidades)
  else if (cenaAtual == 60) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(61); 
        break;
      case "mercurio": mudarCena(62);
        break;
      case "venus": mudarCena(63);
        break;
      case "terra": mudarCena(64);
        break;
      case "marte": mudarCena(65);
        break;
      case "jupiter": mudarCena(66);
        break;
      case "saturno": mudarCena(67);
        break;
      case "urano": mudarCena(68);
        break;
      case "netuno": mudarCena(69);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 5
  else if(cenaAtual == 70){
    switch(mensagemQR){
      case "terra": 
        registrarLog("ACERTO", "P5: Acertou (Terra)"); // LOG ACERTO
        mudarCena(71);
        break;
      default: 
        registrarLog("ERRO", "P5: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[72].definirAudio(this, "errou_sol.mp3"); cenas[72].definirTransicaoTempo(15); break;
          case "mercurio": cenas[72].definirAudio(this, "errou_mercurio.mp3"); cenas[72].definirTransicaoTempo(36); break;
          case "venus": cenas[72].definirAudio(this, "errou_venus.mp3"); cenas[72].definirTransicaoTempo(33); break;
          case "marte": cenas[72].definirAudio(this, "errou_marte.mp3"); cenas[72].definirTransicaoTempo(19); break;
          case "jupiter": cenas[72].definirAudio(this, "errou_jupiter.mp3"); cenas[72].definirTransicaoTempo(35); break;
          case "saturno": cenas[72].definirAudio(this, "errou_saturno.mp3"); cenas[72].definirTransicaoTempo(25); break;
          case "urano": cenas[72].definirAudio(this, "errou_urano.mp3"); cenas[72].definirTransicaoTempo(22); break;
          case "netuno": cenas[72].definirAudio(this, "errou_netuno.mp3"); cenas[72].definirTransicaoTempo(21); break;
        }
        mudarCena(72);
        break;
    }
  }
  
  else if (cenaAtual == 73){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(74);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(84);
      }
  }
  
  //SE ESTIVER NA CENA 74 (Fundo Curiosidades)
  else if (cenaAtual == 74) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(75); 
        break;
      case "mercurio": mudarCena(76);
        break;
      case "venus": mudarCena(77);
        break;
      case "terra": mudarCena(78);
        break;
      case "marte": mudarCena(79);
        break;
      case "jupiter": mudarCena(80);
        break;
      case "saturno": mudarCena(81);
        break;
      case "urano": mudarCena(82);
        break;
      case "netuno": mudarCena(83);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 6
  else if(cenaAtual == 84){
    switch(mensagemQR){
      case "urano": 
        registrarLog("ACERTO", "P6: Acertou (Urano)"); // LOG ACERTO
        mudarCena(85);
        break;
      default: 
        registrarLog("ERRO", "P6: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[86].definirAudio(this, "errou_sol.mp3"); cenas[86].definirTransicaoTempo(15); break;
          case "mercurio": cenas[86].definirAudio(this, "errou_mercurio.mp3"); cenas[86].definirTransicaoTempo(36); break;
          case "venus": cenas[86].definirAudio(this, "errou_venus.mp3"); cenas[86].definirTransicaoTempo(33); break;
          case "terra": cenas[86].definirAudio(this, "errou_terra.mp3"); cenas[86].definirTransicaoTempo(28); break;
          case "marte": cenas[86].definirAudio(this, "errou_marte.mp3"); cenas[86].definirTransicaoTempo(19); break;
          case "jupiter": cenas[86].definirAudio(this, "errou_jupiter.mp3"); cenas[86].definirTransicaoTempo(35); break;
          case "saturno": cenas[86].definirAudio(this, "errou_saturno.mp3"); cenas[86].definirTransicaoTempo(25); break;
          case "netuno": cenas[86].definirAudio(this, "errou_netuno.mp3"); cenas[86].definirTransicaoTempo(21); break;
        }
        mudarCena(86);
        break;
    }
  }
  
  else if (cenaAtual == 87){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(88);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(98);
      }
  }
  
  //SE ESTIVER NA CENA 88 (Fundo Curiosidades)
  else if (cenaAtual == 88) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(89); 
        break;
      case "mercurio": mudarCena(90);
        break;
      case "venus": mudarCena(91);
        break;
      case "terra": mudarCena(92);
        break;
      case "marte": mudarCena(93);
        break;
      case "jupiter": mudarCena(94);
        break;
      case "saturno": mudarCena(95);
        break;
      case "urano": mudarCena(96);
        break;
      case "netuno": mudarCena(97);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 7
  else if(cenaAtual == 98){
    switch(mensagemQR){
      case "mercurio": 
        registrarLog("ACERTO", "P7: Acertou (Mercurio)"); // LOG ACERTO
        mudarCena(99);
        break;
      default: 
        registrarLog("ERRO", "P7: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[100].definirAudio(this, "errou_sol.mp3"); cenas[100].definirTransicaoTempo(15); break;
          case "venus": cenas[100].definirAudio(this, "errou_venus.mp3"); cenas[100].definirTransicaoTempo(33); break;
          case "terra": cenas[100].definirAudio(this, "errou_terra.mp3"); cenas[100].definirTransicaoTempo(28); break;
          case "marte": cenas[100].definirAudio(this, "errou_marte.mp3"); cenas[100].definirTransicaoTempo(19); break;
          case "jupiter": cenas[100].definirAudio(this, "errou_jupiter.mp3"); cenas[100].definirTransicaoTempo(35); break;
          case "saturno": cenas[100].definirAudio(this, "errou_saturno.mp3"); cenas[100].definirTransicaoTempo(25); break;
          case "urano": cenas[100].definirAudio(this, "errou_urano.mp3"); cenas[100].definirTransicaoTempo(22); break;
          case "netuno": cenas[100].definirAudio(this, "errou_netuno.mp3"); cenas[100].definirTransicaoTempo(21); break;
        }
        mudarCena(100);
        break;
    }
  }
  
  else if (cenaAtual == 101){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(102);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(112);
      }
  }
  
  //SE ESTIVER NA CENA 102 (Fundo Curiosidades)
  else if (cenaAtual == 102) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(103); 
        break;
      case "mercurio": mudarCena(104);
        break;
      case "venus": mudarCena(105);
        break;
      case "terra": mudarCena(106);
        break;
      case "marte": mudarCena(107);
        break;
      case "jupiter": mudarCena(108);
        break;
      case "saturno": mudarCena(109);
        break;
      case "urano": mudarCena(110);
        break;
      case "netuno": mudarCena(111);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 8
  else if(cenaAtual == 112){
    switch(mensagemQR){
      case "jupiter": 
        registrarLog("ACERTO", "P8: Acertou (Jupiter)"); // LOG ACERTO
        mudarCena(113);
        break;
      default: 
        registrarLog("ERRO", "P8: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "sol": cenas[114].definirAudio(this, "errou_sol.mp3"); cenas[114].definirTransicaoTempo(15); break;
          case "mercurio": cenas[114].definirAudio(this, "errou_mercurio.mp3"); cenas[114].definirTransicaoTempo(36); break;
          case "venus": cenas[114].definirAudio(this, "errou_venus.mp3"); cenas[114].definirTransicaoTempo(33); break;
          case "terra": cenas[114].definirAudio(this, "errou_terra.mp3"); cenas[114].definirTransicaoTempo(28); break;
          case "marte": cenas[114].definirAudio(this, "errou_marte.mp3"); cenas[114].definirTransicaoTempo(19); break;
          case "saturno": cenas[114].definirAudio(this, "errou_saturno.mp3"); cenas[114].definirTransicaoTempo(25); break;
          case "urano": cenas[114].definirAudio(this, "errou_urano.mp3"); cenas[114].definirTransicaoTempo(22); break;
          case "netuno": cenas[114].definirAudio(this, "errou_netuno.mp3"); cenas[114].definirTransicaoTempo(21); break;
        }
        mudarCena(114);
        break;
    }
  }
  
  else if (cenaAtual == 115){
    if(mensagemQR.equalsIgnoreCase("seletor")){
      mudarCena(116);
    } else if(mensagemQR.equalsIgnoreCase("SeletorQuiz")){
        mudarCena(126);
      }
  }
  
  //SE ESTIVER NA CENA 116 (Fundo Curiosidades)
  else if (cenaAtual == 116) {
    registrarLog("CURIOSIDADE", "Viu sobre: " + mensagemQR); // LOG GERAL
    switch(mensagemQR) {
      case "sol": mudarCena(117); 
        break;
      case "mercurio": mudarCena(118);
        break;
      case "venus": mudarCena(119);
        break;
      case "terra": mudarCena(120);
        break;
      case "marte": mudarCena(121);
        break;
      case "jupiter": mudarCena(122);
        break;
      case "saturno": mudarCena(123);
        break;
      case "urano": mudarCena(124);
        break;
      case "netuno": mudarCena(125);
        break;
    }
  }
  
  //SE ESTIVER NA PERGUNTA 9 (FINAL)
  else if(cenaAtual == 126){
    switch(mensagemQR){
      case "sol": 
        registrarLog("ACERTO", "P9: Acertou (Sol)"); // LOG ACERTO
        registrarLog("FIM_JOGO", "Jogo Concluído com Sucesso"); // LOG FINAL
        salvarRelatorioFinal(); // <<< SALVA O ARQUIVO AQUI
        mudarCena(127);
        break;
      default: 
        registrarLog("ERRO", "P9: Errou (" + mensagemQR + ")"); // LOG ERRO
        switch(mensagemQR) {
          case "mercurio": cenas[128].definirAudio(this, "errou_mercurio.mp3"); cenas[128].definirTransicaoTempo(36); break;
          case "venus": cenas[128].definirAudio(this, "errou_venus.mp3"); cenas[128].definirTransicaoTempo(33); break;
          case "terra": cenas[128].definirAudio(this, "errou_terra.mp3"); cenas[128].definirTransicaoTempo(28); break;
          case "marte": cenas[128].definirAudio(this, "errou_marte.mp3"); cenas[128].definirTransicaoTempo(19); break;
          case "jupiter": cenas[128].definirAudio(this, "errou_jupiter.mp3"); cenas[128].definirTransicaoTempo(35); break;
          case "saturno": cenas[128].definirAudio(this, "errou_saturno.mp3"); cenas[128].definirTransicaoTempo(25); break;
          case "urano": cenas[128].definirAudio(this, "errou_urano.mp3"); cenas[128].definirTransicaoTempo(22); break;
          case "netuno": cenas[128].definirAudio(this, "errou_netuno.mp3"); cenas[128].definirTransicaoTempo(21); break;
        }
        mudarCena(128);
        break;
    }
  }
}

void verificarTransicaoTempo() {
  //Verifica se a cena atual tem transição por tempo
  if (cenas[cenaAtual].usaTempo) {
    int tempoAtual = millis();
    if (tempoAtual - tempoInicioCena > cenas[cenaAtual].tempoTransicao * 1000) {
      //Decide para qual cena ir após o tempo
      int proximaCena = decidirProximaCena();
      mudarCena(proximaCena);
    }
  }
}

void mudarCena(int novaCena) {
  // Descarrega a cena antiga da memória
  if (cenas[cenaAtual] != null) {
    cenas[cenaAtual].resetarAudio();
    cenas[cenaAtual].descarregar();
  }

  if (novaCena >= 0 && novaCena < cenas.length && cenas[novaCena] != null) {
    cenaAtual = novaCena;
    registrarLog("MUDANCA_CENA", "Foi para cena " + novaCena);
    tempoInicioCena = millis();
    
    // Carrega a nova cena na memória agora
    cenas[cenaAtual].carregar(this);
    
    println("Mudou para cena: " + cenas[cenaAtual].nome);
    
  } else {
    println("Erro: Tentativa de mudar para cena inválida: " + novaCena);
  }
}

int decidirProximaCena() {
  //AQUI VOCÊ DEFINE A ORDEM DO SEU JOGO!
  //Esta função decide para onde ir quando uma cena com tempo termina
  
  switch(cenaAtual) {  
    case 1: return 2;
    
    //CURIOSIDADES 1
    case 4: return 2;
    case 5: return 2;
    case 6: return 2;
    case 7: return 2;
    case 8: return 2;
    case 9: return 2;
    case 10: return 2;
    case 11: return 2;
    case 12: return 2;
    
    case 13: return 14;
    
    //PERGUNTA 1
    case 15: return 17;
    case 16: return 14;
    
    //CURIOSIDADES 2
    case 19: return 17;
    case 20: return 17;
    case 21: return 17;
    case 22: return 17;
    case 23: return 17;
    case 24: return 17;
    case 25: return 17;
    case 26: return 17;
    case 27: return 17;
    
    //PERGUNTA 2
    case 29: return 31;
    case 30: return 28;
    
    //CURIOSIDADES 3
    case 33: return 31;
    case 34: return 31;
    case 35: return 31;
    case 36: return 31;
    case 37: return 31;
    case 38: return 31;
    case 39: return 31;
    case 40: return 31;
    case 41: return 31;
    
    //PERGUNTA 3
    case 43: return 45;
    case 44: return 42;
    
    //CURIOSIDADES 4
    case 47: return 45;
    case 48: return 45;
    case 49: return 45;
    case 50: return 45;
    case 51: return 45;
    case 52: return 45;
    case 53: return 45;
    case 54: return 45;
    case 55: return 45;
    
    //PERGUNTA 4
    case 57: return 59;
    case 58: return 56;
    
    //CURIOSIDADES 5
    case 61: return 59;
    case 62: return 59;
    case 63: return 59;
    case 64: return 59;
    case 65: return 59;
    case 66: return 59;
    case 67: return 59;
    case 68: return 59;
    case 69: return 59;
    
    //PERGUNTA 5
    case 71: return 73;
    case 72: return 70;
    
    //CURIOSIDADES 6
    case 75: return 73;
    case 76: return 73;
    case 77: return 73;
    case 78: return 73;
    case 79: return 73;
    case 80: return 73;
    case 81: return 73;
    case 82: return 73;
    case 83: return 73;
    
    //PERGUNTA 6
    case 85: return 87;
    case 86: return 84;
    
    //CURIOSIDADES 7
    case 89: return 87;
    case 90: return 87;
    case 91: return 87;
    case 92: return 87;
    case 93: return 87;
    case 94: return 87;
    case 95: return 87;
    case 96: return 87;
    case 97: return 87;
    
    //PERGUNTA 7
    case 99: return 101;
    case 100: return 98;
    
    //CURIOSIDADES 8
    case 103: return 101;
    case 104: return 101;
    case 105: return 101;
    case 106: return 101;
    case 107: return 101;
    case 108: return 101;
    case 109: return 101;
    case 110: return 101;
    case 111: return 101;
    
    //PERGUNTA 8
    case 113: return 115;
    case 114: return 112;
    
    //CURIOSIDADES 9
    case 117: return 115;
    case 118: return 115;
    case 119: return 115;
    case 120: return 115;
    case 121: return 115;
    case 122: return 115;
    case 123: return 115;
    case 124: return 115;
    case 125: return 115;
    
    //PERGUNTA 9
    case 127: return 129;
    case 128: return 126;
    
    //FIM
    case 129: return 0;
    
    default: return 0;
  }
}

void inicializaCamera(int desiredWidth, int desiredHeight) {
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("Nenhuma câmera disponível!");
    exit();
  } else {
    cam = new Capture(this, desiredWidth, desiredHeight);
    cam.start();
  }
}


void calcularEscalaTela() {
  float ratioTela = (float)width / height;
  float ratioOriginal = LARGURA_ORIGINAL / ALTURA_ORIGINAL;
  
  if (ratioTela > ratioOriginal) {
    destH = height;
    destW = height * ratioOriginal;
    offY = 0;
    offX = (width - destW) / 2; // Centraliza horizontalmente
  }
  
  // Se a tela for mais alta ou igual
  else {
    destW = width;
    destH = width / ratioOriginal;
    offX = 0;
    offY = (height - destH) / 2; // Centraliza verticalmente
  }
}

// Função para adicionar uma linha na tabela
void registrarLog(String tipo, String detalhe) {
  TableRow novaLinha = tabelaLog.addRow();
  novaLinha.setString("Hora", hour() + ":" + minute() + ":" + second());
  novaLinha.setInt("Cena_ID", cenaAtual);
  novaLinha.setString("Tipo_Evento", tipo);
  novaLinha.setString("Detalhe", detalhe);
}

// Função para salvar o arquivo no computador
void salvarRelatorioFinal() {
  // Cria um nome de arquivo com a data e hora (ex: log_2023-10-27_15-30-00.csv)
  String nomeArquivo = "logs/jogo_" + year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "_" + nf(hour(), 2) + "-" + nf(minute(), 2) + "-" + nf(second(), 2) + ".csv";
  
  saveTable(tabelaLog, nomeArquivo);
  println("Relatório salvo em: " + nomeArquivo);
  
  // Limpa a tabela para o próximo jogador não ter os dados do anterior
  tabelaLog.clearRows();
  registrarLog("SISTEMA", "Novo Jogo Iniciado (Reset)");
}

void keyPressed() {
  if (cenaAtual == 0) {
    // Verifica se a tecla pressionada foi o ENTER
    if (key == ENTER) {
      registrarLog("INICIO", "Jogo iniciado pelo teclado (ENTER)"); // Salva no CSV
      mudarCena(1); // Manda para a Cena 1 (Introdução de 5 segundos)
    }
  }
}
