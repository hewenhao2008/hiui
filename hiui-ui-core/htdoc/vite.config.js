import {defineConfig} from 'vite';
import viteCompression from 'vite-plugin-compression';
import vueI18n from '@intlify/vite-plugin-vue-i18n';
import eslint from 'vite-plugin-eslint';
import vue from '@vitejs/plugin-vue';
import path from 'path';
import fs from 'fs';
import AutoImport from 'unplugin-auto-import/vite';

function transformRoutes() {
	let config;

	return {
		name: 'transform-routes',

		configResolved(resolvedConfig) {
			config = resolvedConfig;
		},

		transform(src, id) {
			if (config.command === 'serve') return;

			if (/src\/router\/development\.js$/.test(id)) {
				return {
					code: 'export default function(routes, menus, loginView, layoutView, homeView){}'
				};
			}
		}
	};
}

export default defineConfig(({mode}) => {
	let menus;

	if (mode === 'development') {
		menus = JSON.parse(fs.readFileSync(path.resolve(path.dirname(__dirname), 'files', 'menu.json')));

		const appsDir = path.resolve(path.dirname(path.dirname(__dirname)), 'applications');
		const destDir = path.resolve(__dirname, 'src', 'applications');

		fs.rmSync(destDir, {force: true, recursive: true});

		fs.readdirSync(appsDir).forEach((appName) => {
			const appDir = path.join(appsDir, appName);

			if (!fs.statSync(appDir).isDirectory()) return;

			fs.mkdirSync(path.resolve(destDir, appName), {recursive: true});
			fs.symlinkSync(path.resolve(appDir, 'htdoc'), path.resolve(destDir, appName, 'htdoc'));

			const menuFile = path.resolve(appDir, 'files', 'menu.json');
			if (fs.existsSync(menuFile)) {
				const menu = JSON.parse(fs.readFileSync(menuFile));
				Object.assign(menus, menu);
			}
		});
	}

	return {
		define: {
			__MENUS__: menus
		},
		resolve: {
			preserveSymlinks: true,
			alias: {
				'@': path.resolve(__dirname, 'src')
			}
		},
		build: {
			chunkSizeWarningLimit: 1500,
			rollupOptions: {
				input: {
					index: path.resolve(__dirname, 'hiui.html')
				}
			}
		},
		plugins: [
			transformRoutes(),
			vue(),
			viteCompression({
				deleteOriginFile: true
			}),
			vueI18n({
				compositionOnly: false
			}),
			eslint(),
			AutoImport({
				include: [
					/\.[tj]sx?$/, // .ts, .tsx, .js, .jsx
					/\.vue$/,
					/\.vue\?vue/, // .vue
					/\.md$/ // .md
				],
				dts: true,
				imports: [
					'vue',
					'vue-router',
					{
						'naive-ui': ['useDialog', 'useMessage', 'useNotification', 'useLoadingBar']
					}
				]
			})
		],
		server: {
			proxy: {
				'/hiui-rpc': {
					target: 'http://172.20.10.1',
					secure: false
				},
				'/hiui-upload': {
					target: 'http://192.168.8.1',
					secure: false
				},
				'/hiui-download': {
					target: 'http://192.168.8.1',
					secure: false
				}
			}
		}
	};
});
