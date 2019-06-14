import * as React from "react";
import { map } from "./utils";

export interface MainViewState {
    imageSrc?: string
};

export class MainView extends React.Component<{}, MainViewState> {
    webSocket: WebSocket | null;
    isBinaryProcessing: boolean = false;
    revokeURLs: string[] = [];

    constructor(props: {}) {
        super(props, null);
        this.state = {};
    }

    componentDidMount() {
        this.connect();
    }

    componentDidUpdate() {
        for (const url of this.revokeURLs) {
            URL.revokeObjectURL(url);
        }
        this.revokeURLs = [];
    }

    private connect() {
        const currentURL = new URL(window.location.href);
        const wsURL = new URL(currentURL.origin);
        wsURL.protocol = "ws:"
        wsURL.port = "81";
        console.log(wsURL.href);

        const ws = new WebSocket(wsURL.href);
        this.webSocket = ws;

        ws.onerror = (e) => {
            console.error(e);
            this.showError("websocket error");
        };
        ws.onmessage = (m) => {
            if (m.data instanceof Blob) {
                this.handleBinary(m.data);
            }
        };
    }

    private async handleBinary(blob: Blob) {
        const self = this;

        function read(blob: Blob): Promise<ArrayBuffer> {
            return new Promise((resolve, reject) => {
                const fr = new FileReader();
                fr.onload = () => {
                    resolve(fr.result as ArrayBuffer);
                }
                fr.onerror = (e) => { reject(e); }
                fr.readAsArrayBuffer(blob);    
            });
        }

        async function body() {
            let buf = await read(blob);

            if (buf.byteLength < 4) {
                return;
            }

            let view = new DataView(buf);
            const code = view.getInt32(0, false);
            buf = buf.slice(4);

            switch (code) {
                case 1:
                    const jpeg = new Blob([buf]);
                    const imageSrc = URL.createObjectURL(jpeg);
                    self.setImageSrc(imageSrc);
                    break;
                default:
                    break;
            }
        }

        if (!this.isBinaryProcessing) {
            this.isBinaryProcessing = true;
            await body();
            this.isBinaryProcessing = false;
        }
    }

    setImageSrc(src: string | null) {
        this.setState(ps => {
            const s = { ...ps };
            if (s.imageSrc != null) {
                this.revokeURLs.push(s.imageSrc);
            }
            if (src != null) {
                s.imageSrc = src;
            }
            return s;
        });
    }

    showError(error: string) {
        window.alert(`${error}`);
    }

    render() {
        const image = () => {
            const style: React.CSSProperties = {
                width: "300px",
                height: "300px",
                objectFit: "cover",
                transform: "rotate(90deg)"
            }

            return <img src={this.state.imageSrc} style={style}/>
        }

        return <div>
            {(() => { 
                if (this.state.imageSrc != null) {
                    return image()
                }
            })()}   
        </div>
    }
}