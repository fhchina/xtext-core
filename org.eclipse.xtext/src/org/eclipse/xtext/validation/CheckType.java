/*******************************************************************************
 * Copyright (c) 2008 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/

package org.eclipse.xtext.validation;

/**
 * CheckType is used to determine when @{@link Check}-annotated validation Methods are executed.
 *
 * @author Sven Efftinge - Initial contribution and API
 *
 */
public enum CheckType {
	
	/** Check is executed on editing, save/build and on request. */
	FAST,
	
	/** Check is executed on save/build and request only. */
	NORMAL,
	
	/** Check is executed on request (right click in the editor -&gt; validate) only. */
	EXPENSIVE; 
	
}
