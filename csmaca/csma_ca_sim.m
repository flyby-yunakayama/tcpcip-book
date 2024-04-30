function [CurrentLoad, CurrentTP, PacketLossRate, N_Retry, N_RxPacket] = csma_ca_sim(OfferedLoad, x)
%CSMA_CA_SIM IEEE 802.11aのMACシミュレーション
%   2023/08/01 作成開始
%   2023/08/15 ver1.0完成

  %% パラメータ設定
  
  LightSpeed  = 3e8;
  Frequency   = 5.2e9;
  WaveLength  = LightSpeed/Frequency;    

  T_Step = 1e-6;  % [us]
  T_SIFS = ceil(16e-6/T_Step); 
  T_Slot = ceil(9e-6/T_Step); 
  T_DIFS = ceil(34e-6/T_Step);
  T_DAT  = ceil(544e-6/T_Step);  % 24 Mbps
  T_ACK  = ceil(28e-6/T_Step);   % 24 Mbps

  CW_min = 15;     % [slot]
  CW_max = 1023;   % [slot]

  Retry_lim = 7;
  Thresh_CS = -62; % [dBm]
  Tx_Power  = 23;  % [dBm]
  
  PacketSize  = 12000;  % [bits/packet]

  % AP/端末（ノード）数
  N_node = 3;
  
  % ノード構造体
  for ni = 1:N_node
  
    Node(ni).ID    = ni;
    Node(ni).Pos   = [0, 0];        % x y 座標
    Node(ni).Type  = 'STA';         % 'AP' or 'STA'
    Node(ni).MACState = 'Listen';   % MAC層の状態
    Node(ni).PHYState = 'None';     % PHY層の状態

    Node(ni).TxBuffer  = [];        % 送信バッファ
    Node(ni).RxBuffer  = [];        % 受信バッファ
    Node(ni).Timer     = -1;        % 待機タイマー
    Node(ni).CW        = CW_min;    % コンテンションウィンドウ
    Node(ni).Retry     = 0;         % 再送回数

    Node(ni).RxID      = [];        % 送信元のノードID
    Node(ni).RSSI      = [];        % 受信強度（送信元ノードごとに管理）
    Node(ni).RxCount   = [];        % 受信Packet Portionカウント（送信元ノードごとにカウント）

    Node(ni).N_GenPacket = 0;       % ノードにて発生したパケット数

    % 受信パケットのリスト：送信元ごとにつくる
    for nj = 1:N_node
      Node(ni).RxFrom(nj).List = [];
    end
  end

  % ノードのタイプなど個別に指定
  Node(1).Type  = 'AP';
  Node(2).Pos   = [ x, 10];    
  Node(3).Pos   = [-x, 10]; 

  % シミュレーション時間 [s]
  T_Sim = 10;
  % 時間を進めるステップ数
  N_step = floor(T_Sim/T_Step);

  % トラフィック負荷 [bps]
%   OfferedLoad   = 20e6;    
  % パケット生起確率：ノードごとに一様分布
  Prob_Occ = OfferedLoad*T_Step/PacketSize/N_node;

  % 統計  
  % 生起パケット総数
  N_GenPacket  = 0;
  % 受信成功パケット総数
  N_RxPacket   = 0;
  % 破棄パケット総数
  N_LossPacket = 0;
  % 総再送回数
  N_Retry      = 0;

  for nt = 1:N_step
    % 時間ステップごとの処理
    % 1. トラフィック（パケット）生起
    % 2. MAC
    % 3. PHY
    % の処理を、ノードごとに行う
    
    %% パケット生起
    for nn = 1:N_node
      
      % ノード構造体をいったん取り出す
      TNode = Node(nn);

      % 等確率でパケット生起
      if rand < Prob_Occ

        % 生起したパケット数：ノードで管理
        TNode.N_GenPacket = TNode.N_GenPacket + 1;

        % パケット構造体
        Packet.Type    = 'DAT';
        % 送信元
        Packet.From    = nn;
        % 宛先：乱数で決める
        if strcmp(TNode.Type, 'AP') == 1
          % AP -> STA
          Packet.To = randi([2, N_node]);
        else
          % STA -> AP
          Packet.To = 1;
        end        
        % パケットのインデックス
        Packet.idx   = TNode.N_GenPacket;
        % 再送回数
        Packet.Retry = 0;
        % パケットの時間長
        Packet.Portion = -1;

        % ノードのバッファに追加
        TNode.TxBuffer = [TNode.TxBuffer; Packet];

        % 生起パケット総数
        N_GenPacket = N_GenPacket + 1;
      end

      Node(nn) = TNode;

    end

    %% MAC
    for nn = 1:N_node
      
      % ノード構造体をいったん取り出す
      TNode = Node(nn);

      if strcmp(TNode.PHYState,'Transmit') && strcmp(TNode.MACState,'Receive')
          beep;
      end

      % 状態
      switch TNode.MACState

        % キャリアセンス
        case 'Listen'

          if strcmp(TNode.PHYState, 'Receive') == 1
            % 搬送波を検知したら
            TNode.MACState = 'Receive';          
          else
            % タイマー
            TNode.Timer  = max(0, TNode.Timer - 1);
            if TNode.Timer <= 0
              % バッファにパケットが存在したら、'Backoff'へ
              if numel(TNode.TxBuffer)>0
                TNode.MACState = 'Backoff';
                TNode.Timer = randi([0 TNode.CW])*T_Slot;
              end
            end
          end

        % ランダムバックオフ
        case 'Backoff'
          
          if strcmp(TNode.PHYState, 'Receive') == 1
            % 搬送波を検知したら
            TNode.MACState = 'Receive';          
          else
            %　バックオフタイマーが0になったら'Transmit'
            TNode.Timer = max(0, TNode.Timer - 1);
            if TNode.Timer == 0
              TNode.MACState = 'Transmit';
              TNode.TxBuffer(1).Portion = T_DAT;
            end
          end

        % パケット送信
        case 'Transmit'

          % タイマー
          TNode.Timer  = max(0, TNode.Timer - 1);
          if TNode.Timer <= 0
            TNode.PHYState = 'Transmit';
          end

        % ACK待ち
        case 'WaitACK'

          % 再送タイマーを減らす
          TNode.Timer  = max(0, TNode.Timer - 1);  

          % ACKを受信しなければ再送：'Backoff'からやり直し
          if TNode.Timer <= 0

            if TNode.Retry >= Retry_lim
              % 再送回数上限：パケットを破棄：'Listen'へ
              TNode.MACState  = 'Listen';
              TNode.Retry  = 0;
              TNode.Timer  = T_DIFS;
              % 自身のバッファから削除
              TNode.TxBuffer(1) = [];

              N_LossPacket = N_LossPacket + 1;

            else
              % 再送
              TNode.Retry = TNode.Retry + 1;
              TNode.MACState = 'Backoff';
              TNode.CW    = min((CW_min+1)*2^TNode.Retry - 1, CW_max);
              TNode.Timer = randi([0 TNode.CW])*T_Slot;

              N_Retry = N_Retry + 1;
            end
          end
        
        % 受信/送信待機状態
        case 'Receive'          

      end

      Node(nn) = TNode;
      
    end
    
    %% PHY
    for nn = 1:N_node

      % ノード構造体をいったん取り出す
      TNode = Node(nn);
      switch TNode.PHYState

        case 'Transmit'

          % 周辺ノードへ送信          
          for ni = 1:N_node
            if ni == nn, continue, end
            
            % 相手ノードの構造体
            RNode = Node(ni);

            % 信号伝達
            Distance = norm([RNode.Pos, TNode.Pos]);
            Rx_Power  = Tx_Power - 20*log10(4*pi*Distance/WaveLength);
            
            % 受信感度以上，かつ送信中でなければ受信処理へ
            if Rx_Power >= Thresh_CS && strcmp(RNode.PHYState,'Transmit') ~= 1

              % 複数のノードからの受信パケットを管理
              RIdx = find(RNode.RxID == nn);

              if TNode.TxBuffer(1).Portion > 0
                
                % あるパケットを初めて受信するとき
                if numel(RIdx) == 0
                  RNode.RxID  = [RNode.RxID, nn];
                  RNode.RSSI = [RNode.RSSI, Rx_Power];
                  RNode.RxCount = [RNode.RxCount, 0];
                  RIdx = numel(RNode.RxID);
                end

                RNode.RxCount(RIdx) = RNode.RxCount(RIdx) + 1;

              else

                % 送信完了後：宛先へパケット受け渡し
                RNode.RxBuffer = TNode.TxBuffer(1);   

                % 受信パケットリストから送信元ノードの情報を削除
                RNode.RxID(RIdx)    = [];
                RNode.RSSI(RIdx)   = [];
                RNode.RxCount(RIdx) = [];            

              end

              % 物理層の状態遷移処理

              % ひとつのノードから受信している場合：'Receive'
              if numel(RNode.RxID) == 1 && strcmp(RNode.PHYState,'Collision') ~= 1
                RNode.PHYState = 'Receive';
                RNode.MACState = 'Receive';
              end

              % 複数のノードから受信している場合：'Collision'
              if numel(RNode.RxID) > 1 % && prod(RNode.RxID == nn) == 0
                RNode.PHYState = 'Collision';
                RNode.MACState = 'Receive';
              end

            end

            Node(ni) = RNode;

          end

          % 送信パケットのカウントを減らす         
          TNode.TxBuffer(1).Portion = TNode.TxBuffer(1).Portion - 1;

          % 送信を終えたら
          if TNode.TxBuffer(1).Portion < 0
            switch TNode.TxBuffer(1).Type
              case 'DAT'
                TNode.MACState = 'WaitACK';
                TNode.PHYState = 'None';
                % 再送タイマー
                TNode.Timer = T_SIFS + T_DIFS + T_ACK;

              case 'ACK'
                TNode.MACState = 'Listen';
                TNode.PHYState = 'None';
                % DIFS
                TNode.Timer  = T_DIFS;
                % 自身のバッファから削除
                TNode.TxBuffer(1) = [];
            end
          end
          
        case 'Receive'

          % 受信レベルが0=受信を終えたら、かつ衝突が無ければ
            if numel(TNode.RSSI) == 0

              switch TNode.RxBuffer(1).Type
                
                case 'DAT'
                  
                  if TNode.RxBuffer(1).To == TNode.ID
                    % 自分宛てだったらACK 送信
                    % パケット構造体
                    Packet.Type    = 'ACK';
                    Packet.From    = TNode.ID;
                    Packet.To      = TNode.RxBuffer(1).From;
                    Packet.Portion = T_ACK;

                    % ノードのバッファ先頭に挿入
                    TNode.TxBuffer = [Packet; TNode.TxBuffer];
                    TNode.MACState = 'Transmit';
                    TNode.PHYState = 'None';

                    % ACK送信前にSIFS待つ
                    TNode.Timer  = T_SIFS;

                    % 受信成功パケットのリスト
                    nj = TNode.RxBuffer(1).From;
                    TNode.RxFrom(nj).List = [TNode.RxFrom(nj).List; TNode.RxBuffer(1).idx];

                  else

                    % 自分宛てではなかったら，タイマー繰り越し
                    TNode.MACState = 'Listen';
                    TNode.PHYState = 'None';
                    % DIFS
                    TNode.Timer  = TNode.Timer + T_SIFS + T_ACK + T_DIFS;

                  end

                  % 受信バッファをクリア
                  TNode.RxBuffer(1) = [];                  

                case 'ACK'

                  if TNode.RxBuffer(1).To == TNode.ID
                    % 自分宛てのACKだったら：送信成功、'Listen'へ
                    TNode.MACState  = 'Listen';
                    TNode.PHYState = 'None';
                    TNode.Retry  = 0;
                    TNode.Timer  = T_DIFS;

                    % 自身のバッファから削除
                    TNode.TxBuffer(1) = [];

                    % 総受信パケットをカウント
                    N_RxPacket = N_RxPacket + 1;

                  else
                    % 自分宛てではなかったら：そのまま'Listen'へ
                    TNode.MACState  = 'Listen';
                    TNode.PHYState = 'None';

                  end

                  % 受信バッファをクリア
                  TNode.RxBuffer(1) = [];

              end
            end

        % 受信（パケット衝突状態）
        case 'Collision'

            % 受信レベルが0=受信を終えたら
            if numel(TNode.RSSI) == 0
              % 衝突している状態なので信号を復調できない⇒'Listen'
              TNode.MACState = 'Listen';
              TNode.PHYState = 'None';
              TNode.Timer  = TNode.Timer + T_DIFS; % T_SIFS + T_ACK + T_DIFS;  % T_DIFS; 
            end

        case 'None'

      end

      Node(nn) = TNode;

    end

    %% システム性能
    % 現時点でのトラフィック負荷
    CurrentLoad = N_GenPacket*PacketSize/(T_Step*nt);
    % 現時点でのシステムスループット
    CurrentTP   = N_RxPacket*PacketSize/(T_Step*nt);    
    % パケット損失率
    PacketLossRate = N_LossPacket/(N_RxPacket+N_LossPacket)*100;

    % 途中経過をコマンドウィンドウに表示
    if mod(nt,100)==0
      clc;
      fprintf([' Offered Load  = %2.2f Mbps, N_GenPacket = %d, \n' ...
               ' Throughput    = %2.2f Mbps, N_Rx_Packet = %d \n' ...
               ' Retry Count   = %d,   Packet Loss Rate = %d \n'], ... 
               CurrentLoad/1e6, N_GenPacket, CurrentTP/1e6, N_RxPacket, N_Retry, PacketLossRate);
      pause(0.01);
    end

  end

end

