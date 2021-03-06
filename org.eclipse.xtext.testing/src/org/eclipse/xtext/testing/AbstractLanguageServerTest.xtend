/*******************************************************************************
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.testing

import com.google.inject.AbstractModule
import com.google.inject.Guice
import com.google.inject.Inject
import java.io.File
import java.io.FileWriter
import java.net.URI
import java.nio.file.Path
import java.nio.file.Paths
import java.util.List
import java.util.Map
import java.util.concurrent.CompletableFuture
import org.eclipse.lsp4j.ColoringInformation
import org.eclipse.lsp4j.ColoringParams
import org.eclipse.lsp4j.CompletionItem
import org.eclipse.lsp4j.CompletionList
import org.eclipse.lsp4j.Diagnostic
import org.eclipse.lsp4j.DidChangeWatchedFilesParams
import org.eclipse.lsp4j.DidCloseTextDocumentParams
import org.eclipse.lsp4j.DidOpenTextDocumentParams
import org.eclipse.lsp4j.DocumentFormattingParams
import org.eclipse.lsp4j.DocumentHighlight
import org.eclipse.lsp4j.DocumentHighlightKind
import org.eclipse.lsp4j.DocumentRangeFormattingParams
import org.eclipse.lsp4j.DocumentSymbolParams
import org.eclipse.lsp4j.FileChangeType
import org.eclipse.lsp4j.FileEvent
import org.eclipse.lsp4j.Hover
import org.eclipse.lsp4j.InitializeParams
import org.eclipse.lsp4j.InitializeResult
import org.eclipse.lsp4j.Location
import org.eclipse.lsp4j.Position
import org.eclipse.lsp4j.PublishDiagnosticsParams
import org.eclipse.lsp4j.Range
import org.eclipse.lsp4j.ReferenceContext
import org.eclipse.lsp4j.ReferenceParams
import org.eclipse.lsp4j.SignatureHelp
import org.eclipse.lsp4j.SymbolInformation
import org.eclipse.lsp4j.TextDocumentIdentifier
import org.eclipse.lsp4j.TextDocumentItem
import org.eclipse.lsp4j.TextDocumentPositionParams
import org.eclipse.lsp4j.TextEdit
import org.eclipse.lsp4j.WorkspaceSymbolParams
import org.eclipse.lsp4j.jsonrpc.Endpoint
import org.eclipse.lsp4j.jsonrpc.services.ServiceEndpoints
import org.eclipse.lsp4j.services.LanguageClientExtensions
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.LanguageInfo
import org.eclipse.xtext.ide.server.Document
import org.eclipse.xtext.ide.server.LanguageServerImpl
import org.eclipse.xtext.ide.server.ServerModule
import org.eclipse.xtext.ide.server.UriExtensions
import org.eclipse.xtext.ide.server.concurrent.RequestManager
import org.eclipse.xtext.resource.IResourceServiceProvider
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.util.Files
import org.eclipse.xtext.util.Modules2
import org.junit.Assert
import org.junit.Before

/**
 * @author Sven Efftinge - Initial contribution and API
 */
@FinalFieldsConstructor
abstract class AbstractLanguageServerTest implements Endpoint {

	@Accessors
	protected val String fileExtension

	@Before
	def void setup() {
		val module = Modules2.mixin(new ServerModule, new AbstractModule() {

			override protected configure() {
				bind(RequestManager).toInstance(new RequestManager() {

					override <V> runWrite((CancelIndicator)=>V writeRequest) {
						return CompletableFuture.completedFuture(writeRequest.apply [ false ])
					}

					override <V> runRead((CancelIndicator)=>V readRequest) {
						return CompletableFuture.completedFuture(readRequest.apply [ false ])
					}

				})
			}

		})

		val injector = Guice.createInjector(module)
		injector.injectMembers(this)

		val resourceServiceProvider = resourceServerProviderRegistry.extensionToFactoryMap.get(fileExtension)
		if (resourceServiceProvider instanceof IResourceServiceProvider)
			languageInfo = resourceServiceProvider.get(LanguageInfo)

		// register notification callbacks
		languageServer.connect(ServiceEndpoints.toServiceObject(this, LanguageClientExtensions))
		// initialize
		languageServer.supportedMethods()

		// create workingdir
		root = new File(new File("").absoluteFile, "/test-data/test-project")
		if (!root.mkdirs) {
			Files.cleanFolder(root, null, true, false)
		}
		root.deleteOnExit
	}

	@Inject
	protected IResourceServiceProvider.Registry resourceServerProviderRegistry

	@Inject extension UriExtensions
	@Inject protected LanguageServerImpl languageServer

	protected List<Pair<String, Object>> notifications = newArrayList()
	protected File root
	protected LanguageInfo languageInfo

	protected def Path getTestRootPath() {
		root.toPath().toAbsolutePath().normalize()
	}

	protected def Path relativize(String uri) {
		val path = Paths.get(new URI(uri))
		testRootPath.relativize(path)
	}

	protected def InitializeResult initialize() {
		return initialize(null)
	}

	protected def InitializeResult initialize((InitializeParams)=>void initializer) {
		val params = new InitializeParams => [
			processId = 1
			rootPath = testRootPath.toString
		]
		initializer?.apply(params as InitializeParams)
		return languageServer.initialize(params).get
	}

	protected def void open(String fileUri, String model) {
		open(fileUri, languageInfo.languageName, model)
	}

	protected def void open(String fileUri, String langaugeId, String model) {
		languageServer.didOpen(new DidOpenTextDocumentParams => [
			uri = fileUri
			textDocument = new TextDocumentItem => [
				uri = fileUri
				languageId = langaugeId
				version = 1
				text = model
			]
		])
	}

	protected def void didCreateWatchedFiles(String ... fileUris) {
		languageServer.didChangeWatchedFiles(new DidChangeWatchedFilesParams => [
			for (fileUri : fileUris) {
				changes += new FileEvent => [
					uri = fileUri
					it.type = FileChangeType.Created
				]
			}
		])
	}

	protected def void close(String fileUri) {
		languageServer.didClose(new DidCloseTextDocumentParams => [
			textDocument = new TextDocumentIdentifier(fileUri)
		])
	}

	def String writeFile(String path, CharSequence contents) {
		val file = new File(root, path)
		file.parentFile.mkdirs
		file.createNewFile

		val writer = new FileWriter(file)
		writer.write(contents.toString)
		writer.close

		return file.toURI.normalize.toPath
	}

	def String getVirtualFile(String path) {
		val file = new File(root, path)
		return file.toURI.normalize.toPath
	}

	protected def dispatch String toExpectation(List<?> elements) '''
		�FOR element : elements�
			�element.toExpectation�
		�ENDFOR�
	'''
	protected def dispatch String toExpectation(String it) { it }
	
	protected def dispatch String toExpectation(Integer it) { '''�it�''' }
	
	protected def dispatch String toExpectation(Void it) { '' }

	protected def dispatch String toExpectation(Location it) '''�uri.relativize� �range.toExpectation�'''

	protected def dispatch String toExpectation(Range it) '''[�start.toExpectation� .. �end.toExpectation�]'''

	protected def dispatch String toExpectation(Position it) '''[�line�, �character�]'''

	protected def dispatch String toExpectation(SymbolInformation it) '''
		symbol "�name�" {
		    kind: �kind.value�
		    location: �location.toExpectation�
		    �IF !containerName.nullOrEmpty�
		    	container: "�containerName�"
		    �ENDIF�
		}
	'''

	protected def dispatch String toExpectation(CompletionItem it) '''
		�label��IF !detail.nullOrEmpty� (�detail�)�ENDIF��IF textEdit !== null� -> �textEdit.toExpectation��ELSEIF insertText !== null && insertText != label� -> �insertText��ENDIF�
	'''

	protected dispatch def String toExpectation(TextEdit it) '''
		�newText� �range.toExpectation�
	'''

	protected dispatch def String toExpectation(Hover it) '''
		�range.toExpectation�
		�FOR content : contents�
			�content.toExpectation�
		�ENDFOR�
	'''

	protected dispatch def String toExpectation(SignatureHelp it) {
		if (signatures.size === 0) {
			Assert.
				assertNull('''Signature index is expected to be null when no signatures are available. Was: �activeSignature�.''',
					activeSignature);
			return '<empty>';
		}
		Assert.assertNotNull('Active signature index must not be null when signatures are available.', activeSignature);
		val param = if(activeParameter === null) '<empty>' else signatures.get(activeSignature).parameters.get(
				activeParameter).label;
		'''�signatures.map[label].join(' | ')� | �param�''';
	}

	protected dispatch def String toExpectation(DocumentHighlight it) {
		val rangeString = '''�IF range === null�[NaN, NaN]:[NaN, NaN]�ELSE��range.toExpectation��ENDIF�''';
		'''�IF kind === null�NaN�ELSE��kind.toExpectation��ENDIF� �rangeString�'''
	}

	protected dispatch def String toExpectation(DocumentHighlightKind kind) {
		return kind.toString.substring(0, 1).toUpperCase;
	}
	
	protected dispatch def String toExpectation(Map<Object, Object> it) {
		val sb = new StringBuilder;
		entrySet.forEach[
			if (sb.length > 0) {
				sb.append('\n');
			}
			sb.append(key.toExpectation);
			sb.append(' ->');
			if (value instanceof Iterable<?>) {
				(value as Iterable<?>).forEach[
					sb.append('\n * ');
					sb.append(toExpectation);
				]
			} else {
				sb.append(' ');
				sb.append(value.toExpectation);
			}
 		];
		return sb.toString;
	}
	
	protected dispatch def String toExpectation(ColoringInformation it) {
		return '''�range.toExpectation� -> [�styles.join(', ')�]''';
	}

	protected def void testCompletion((TestCompletionConfiguration)=>void configurator) {
		val extension configuration = new TestCompletionConfiguration
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)
		val filePath = initializeContext(configuration).uri
		val completionItems = languageServer.completion(new TextDocumentPositionParams => [
			textDocument = new TextDocumentIdentifier(filePath)
			position = new Position(line, column)
		])

		val list = completionItems.get
		// assert ordered by sortText
		Assert.assertEquals(list.items, list.items.sortBy[sortText].toList)
		if (configuration.assertCompletionList !== null) {
			configuration.assertCompletionList.apply(list)
		} else {
			val actualCompletionItems = list.items.toExpectation
			assertEquals(expectedCompletionItems, actualCompletionItems)
		}
	}

	protected def FileInfo initializeContext(TextDocumentConfiguration configuration) {
		initialize
		// create files on disk and notify languageServer
		if (!configuration.filesInScope.isEmpty) {
			val createdFiles = configuration.filesInScope.entrySet.map[key.writeFile(value.toString)]
			didCreateWatchedFiles(createdFiles)

			if (configuration.model === null) {
				return new FileInfo(createdFiles.head, configuration.filesInScope.entrySet.head.value.toString)
			}
		}
		Assert.assertNotNull(configuration.model)
		val filePath = configuration.filePath.writeFile(configuration.model)
		open(filePath, configuration.model)
		return new FileInfo(filePath, configuration.model)
	}

	protected def void testDefinition((DefinitionTestConfiguration)=>void configurator) {
		val extension configuration = new DefinitionTestConfiguration
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)
		val fileUri = initializeContext(configuration).uri
		val definitionsFuture = languageServer.definition(new TextDocumentPositionParams => [
			textDocument = new TextDocumentIdentifier(fileUri)
			position = new Position(line, column)
		])
		val definitions = definitionsFuture.get
		if (configuration.assertDefinitions !== null) {
			configuration.assertDefinitions.apply(definitions)
		} else {
			val actualDefinitions = definitions.toExpectation
			assertEquals(expectedDefinitions, actualDefinitions)
		}
	}

	protected def void testHover((HoverTestConfiguration)=>void configurator) {
		val extension configuration = new HoverTestConfiguration
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)
		val fileUri = initializeContext(configuration).uri

		val hoverFuture = languageServer.hover(new TextDocumentPositionParams => [
			textDocument = new TextDocumentIdentifier(fileUri)
			position = new Position(line, column)
		])
		val hover = hoverFuture.get
		if (configuration.assertHover !== null) {
			configuration.assertHover.apply(hover)
		} else {
			val actualHover = hover.toExpectation
			assertEquals(expectedHover, actualHover)
		}
	}

	protected def testSignatureHelp((SignatureHelpConfiguration)=>void configurator) {
		val extension configuration = new SignatureHelpConfiguration;
		configuration.filePath = 'MyModel.' + fileExtension;
		configurator.apply(configuration);

		val fileUri = initializeContext(configuration).uri

		val signatureHelpFuture = languageServer.signatureHelp(new TextDocumentPositionParams => [
			textDocument = new TextDocumentIdentifier(fileUri)
			position = new Position(line, column)
		]);
		val signatureHelp = signatureHelpFuture.get
		if (configuration.assertSignatureHelp !== null) {
			configuration.assertSignatureHelp.apply(signatureHelp)
		} else {
			val actualSignatureHelp = signatureHelp.toExpectation
			assertEquals(expectedSignatureHelp.trim, actualSignatureHelp.trim)
		}
	}

	protected def testDocumentHighlight((DocumentHighlightConfiguration)=>void configurator) {
		val extension configuration = new DocumentHighlightConfiguration => [
			filePath = '''MyModel.�fileExtension�''';
		];
		configurator.apply(configuration);

		val fileUri = initializeContext(configuration).uri;
		val highlights = languageServer.documentHighlight(new TextDocumentPositionParams => [
			textDocument = new TextDocumentIdentifier(fileUri)
			position = new Position(line, column)
		]);

		val actualDocumentHighlight = highlights.get.map[toExpectation].join(' | ');
		assertEquals(expectedDocumentHighlight, actualDocumentHighlight);
	}

	protected def void testDocumentSymbol((DocumentSymbolConfiguraiton)=>void configurator) {
		val extension configuration = new DocumentSymbolConfiguraiton
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)

		val fileUri = initializeContext(configuration).uri
		val symbolsFuture = languageServer.documentSymbol(new DocumentSymbolParams(new TextDocumentIdentifier(fileUri)))
		val symbols = symbolsFuture.get
		if (configuration.assertSymbols !== null) {
			configuration.assertSymbols.apply(symbols)
		} else {
			val String actualSymbols = symbols.toExpectation
			assertEquals(expectedSymbols, actualSymbols)
		}
	}

	protected def void testSymbol((WorkspaceSymbolConfiguraiton)=>void configurator) {
		val extension configuration = new WorkspaceSymbolConfiguraiton
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)

		initializeContext(configuration)
		val symbols = languageServer.symbol(new WorkspaceSymbolParams(query)).get
		if (configuration.assertSymbols !== null) {
			configuration.assertSymbols.apply(symbols)
		} else {
			val String actualSymbols = symbols.toExpectation
			assertEquals(expectedSymbols, actualSymbols)
		}
	}

	protected def void testReferences((ReferenceTestConfiguration)=>void configurator) {
		val extension configuration = new ReferenceTestConfiguration
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)
		val fileUri = initializeContext(configuration).uri
		val referencesFuture = languageServer.references(new ReferenceParams => [
			textDocument = new TextDocumentIdentifier(fileUri)
			position = new Position(line, column)
			context = new ReferenceContext(includeDeclaration)
		])
		val references = referencesFuture.get
		if (configuration.assertReferences !== null) {
			configuration.assertReferences.apply(references)
		} else {
			val actualReferences = references.toExpectation
			assertEquals(expectedReferences, actualReferences)
		}
	}

	def void assertEquals(String expected, String actual) {
		Assert.assertEquals(expected.replace('\t', '    '), actual.replace('\t', '    '))
	}

	protected def testFormatting((FormattingConfiguration)=>void configurator) {
		val extension configuration = new FormattingConfiguration
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)
		val fileInfo = initializeContext(configuration)

		val changes = languageServer.formatting(new DocumentFormattingParams => [
			textDocument = new TextDocumentIdentifier(fileInfo.uri)
		])
		val result = new Document(1, fileInfo.contents).applyChanges(<TextEdit>newArrayList(changes.get()).reverse)
		assertEquals(configuration.expectedText, result.contents)
	}

	protected def testRangeFormatting((RangeFormattingConfiguration)=>void configurator) {
		val extension configuration = new RangeFormattingConfiguration
		configuration.filePath = 'MyModel.' + fileExtension
		configurator.apply(configuration)

		val fileInfo = initializeContext(configuration)

		val changes = languageServer.rangeFormatting(new DocumentRangeFormattingParams => [
			textDocument = new TextDocumentIdentifier(fileInfo.uri)
			range = configuration.range
		])
		val result = new Document(1, fileInfo.contents).applyChanges(<TextEdit>newArrayList(changes.get()).reverse)
		assertEquals(configuration.expectedText, result.contents)
	}

	override notify(String method, Object parameter) {
		this.notifications.add(method -> parameter)
	}
	
	override request(String method, Object parameter) {
		return CompletableFuture.completedFuture(null)
	}
	
	protected def Map<String, List<Diagnostic>> getDiagnostics() {
		val result = <String, List<Diagnostic>>newHashMap
		for (diagnostic : notifications.map[value].filter(PublishDiagnosticsParams)) {
			result.put(diagnostic.uri, diagnostic.diagnostics)
		}
		return result 
	}
	
	protected def getColoringParams() {
		return notifications.map[value].filter(ColoringParams).toMap([uri], [infos]);
	}
}

@Data class FileInfo {
	String uri
	String contents
}

@Accessors
class TestCompletionConfiguration extends TextDocumentPositionConfiguration {
	String expectedCompletionItems = ''
	(CompletionList)=>void assertCompletionList = null
}

@Accessors
class DefinitionTestConfiguration extends TextDocumentPositionConfiguration {
	String expectedDefinitions = ''
	(List<? extends Location>)=>void assertDefinitions = null
}

@Accessors
class HoverTestConfiguration extends TextDocumentPositionConfiguration {
	String expectedHover = ''
	(Hover)=>void assertHover = null
}

@Accessors
class SignatureHelpConfiguration extends TextDocumentPositionConfiguration {
	String expectedSignatureHelp = ''
	(SignatureHelp)=>void assertSignatureHelp = null
}

@Accessors
class DocumentHighlightConfiguration extends TextDocumentPositionConfiguration {
	String expectedDocumentHighlight = ''
}

@Accessors
class DocumentSymbolConfiguraiton extends TextDocumentConfiguration {
	String expectedSymbols = ''
	(List<? extends SymbolInformation>)=>void assertSymbols = null
}

@Accessors
class ReferenceTestConfiguration extends TextDocumentPositionConfiguration {
	boolean includeDeclaration = false
	String expectedReferences = ''
	(List<? extends Location>)=>void assertReferences = null
}

@Accessors
class WorkspaceSymbolConfiguraiton extends TextDocumentConfiguration {
	String query = ''
	String expectedSymbols = ''
	(List<? extends SymbolInformation>)=>void assertSymbols = null
}

@Accessors
class TextDocumentPositionConfiguration extends TextDocumentConfiguration {
	int line = 0
	int column = 0
}

@Accessors
class TextDocumentConfiguration {
	Map<String, CharSequence> filesInScope = emptyMap
	String model
	String filePath
}

@Accessors
class FormattingConfiguration extends TextDocumentConfiguration {
	String expectedText = ''
}

@Accessors
class ColoringConfiguration extends TextDocumentConfiguration {
	String expectedColoredRangesWithStyles = '';
}

@Accessors
class RangeFormattingConfiguration extends FormattingConfiguration {
	Range range = new Range => [
		start = new Position(0, 0)
		end = new Position(0, 1)
	]
}
