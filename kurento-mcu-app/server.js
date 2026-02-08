/* server.js - MCU */
const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const kurento = require('kurento-client');

const app = express();
const server = http.createServer(app);
const io = socketIO(server);

// [환경 변수] Kurento 서버 주소 (Host Mode이므로 localhost)
const KURENTO_URI = 'ws://localhost:8888/kurento';

// [전역 변수]
let kurentoClient = null;
let pipeline = null;
let composite = null; // MCU 믹서 객체

// 사용자 세션 관리 (Socket ID -> User Session)
const clients = {};

app.use(express.static('public'));

/* =========================================================
   1. Socket.io 시그널링 처리
   ========================================================= */
io.on('connection', (socket) => {
    console.log(`[Connect] User connected: ${socket.id}`);

    socket.on('message', (message) => {
        switch (message.id) {
            case 'joinRoom':
                joinRoom(socket, message);
                break;
            case 'onIceCandidate':
                addIceCandidate(socket, message);
                break;
            case 'leaveRoom':
                leaveRoom(socket);
                break;
            default:
                socket.emit('error', { message: 'Invalid message ' + message.id });
        }
    });
});

/* =========================================================
   2. MCU 핵심 로직 (Join Room)
   ========================================================= */
function joinRoom(socket, message) {
    // 1. Kurento Client 및 파이프라인 확보
    getKurentoPipeline((error, _pipeline) => {
        if (error) return sendError(socket, error);

        // 2. Composite(믹서) 확보
        getComposite(_pipeline, (error, _composite) => {
            if (error) return sendError(socket, error);

            // 3. 사용자 전용 WebRtcEndpoint 생성 (통신용)
            _pipeline.create('WebRtcEndpoint', (error, webRtcEndpoint) => {
                if (error) return sendError(socket, error);

                // 4. Composite에 꽂을 HubPort 생성 (믹싱용)
                _composite.createHubPort((error, hubPort) => {
                    if (error) return sendError(socket, error);

                    // [세션 저장] 나중에 연결 끊을 때 쓰려고 저장함
                    clients[socket.id] = {
                        id: socket.id,
                        webRtcEndpoint: webRtcEndpoint,
                        hubPort: hubPort
                    };

                    // 5. ICE Candidate 이벤트 핸들러 (Kurento가 찾은 후보를 클라에게 전송)
                    webRtcEndpoint.on('IceCandidateFound', (event) => {
                        console.log('[DEBUG] Server generated candidate'); // 이 로그가 뜨는지 확인!
                        const candidate = kurento.getComplexType('IceCandidate')(event.candidate);
                        socket.emit('message', {
                            id: 'iceCandidate',
                            candidate: candidate
                        });
                    });

                    // 6. [핵심] 배관 연결 (Wiring)
                    // (1) 사용자 -> 믹서 (내 영상을 믹서에 넣음)
                    webRtcEndpoint.connect(hubPort, (error) => {
                        if (error) return sendError(socket, error);
                        
                        // (2) 믹서 -> 사용자 (합쳐진 영상을 내가 받음)
                        hubPort.connect(webRtcEndpoint, (error) => {
                            if (error) return sendError(socket, error);

                            // 7. SDP 협상 (Offer 처리 -> Answer 생성)
                            webRtcEndpoint.processOffer(message.sdpOffer, (error, sdpAnswer) => {
                                if (error) return sendError(socket, error);

                                // 8. Answer 전송 & ICE 수집 시작
                                socket.emit('message', {
                                    id: 'joinResponse',
                                    sdpAnswer: sdpAnswer
                                });
                                webRtcEndpoint.gatherCandidates((error) => {
                                    if (error) return sendError(socket, error);
                                });
                                
                                console.log(`[Success] User ${socket.id} joined MCU room!`);
                            });
                        });
                    });
                });
            });
        });
    });
}

function addIceCandidate(socket, message) {
    const user = clients[socket.id];
    if (user) {
        const candidate = kurento.getComplexType('IceCandidate')(message.candidate);
        user.webRtcEndpoint.addIceCandidate(candidate);
    }
}

function leaveRoom(socket) {
    const user = clients[socket.id];
    if (user) {
        user.webRtcEndpoint.release();
        user.hubPort.release(); // 믹서 구멍도 닫아줌
        delete clients[socket.id];
        console.log(`[Disconnect] User ${socket.id} left.`);
        
        // (참고) 마지막 사용자가 나가면 파이프라인도 닫아주는 로직을 추가할 수 있음
    }
}

/* =========================================================
   3. Kurento 객체 관리 (Singleton Pattern)
   ========================================================= */
function getKurentoPipeline(callback) {
    if (pipeline !== null) return callback(null, pipeline);

    kurento(KURENTO_URI, (error, _kurentoClient) => {
        if (error) return callback("Could not find media server at " + KURENTO_URI);
        
        kurentoClient = _kurentoClient;
        _kurentoClient.create('MediaPipeline', (error, _pipeline) => {
            if (error) return callback(error);
            pipeline = _pipeline;
            callback(null, pipeline);
        });
    });
}

function getComposite(_pipeline, callback) {
    if (composite !== null) return callback(null, composite);

    _pipeline.create('Composite', (error, _composite) => {
        if (error) return callback(error);
        composite = _composite;
        callback(null, composite);
    });
}

function sendError(socket, error) {
    console.error(error);
    socket.emit('error', { message: error });
}

// 서버 시작
const PORT = 3000;
server.listen(PORT, () => {
    console.log(`[MCU Server] Running on port ${PORT}`);
});