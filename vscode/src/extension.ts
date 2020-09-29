import * as path from 'path';
import * as net from 'net';
import { workspace, ExtensionContext } from 'vscode';

import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  StreamInfo,
  TransportKind
} from 'vscode-languageclient';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
	console.log('Congratulations, your extension "sorbetor" is now active!');
	
	let rubyMainFile = "/Users/jeremie/git/sorbetor/bin/sorbetor";
	let serverOptions: ServerOptions = async () => {
		let socket: net.Socket = net.createConnection({ host: "localhost", port: 8876 });
		return { reader: socket, writer: socket };
	};
  
	let clientOptions: LanguageClientOptions = {
	  documentSelector: [{ scheme: 'file', language: 'rbt' }],
	};
  
	client = new LanguageClient(
	  'sorbetor',
	  'Sorbetor Language Server',
	  serverOptions,
	  clientOptions
	);

	client.start();
}

export function deactivate(): Thenable<void> | undefined {
	if (!client) {
	  return undefined;
	}
	return client.stop();
}
  
