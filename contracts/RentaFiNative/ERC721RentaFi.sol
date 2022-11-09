// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721RentaFi is Context, ERC165, IERC721, IERC721Metadata {
  using Address for address;
  using Strings for uint256;

  // Token name
  string private _name;

  // Token symbol
  string private _symbol;

  // Mapping from token ID to OwnerInfo
  mapping(uint256 => OwnerInfo) public _owners; // Borrower's info

  // Array with all token ids, used for enumeration
  uint256[] public _allTokens;

  struct OwnerInfo {
    address owner; // address of user role
    address lender;
    uint256 expires; // unix timestamp, user expires
  }

  // RentaFi Native
  mapping(uint256 => address) private _superOwners; // as a ERC721.owners

  // Mapping owner address to token count
  mapping(address => uint256) private _balances; // Borrower's balance

  // RentaFi Native
  mapping(address => uint256) private _superOwnerBalances; // as a ERC721.balances

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  /**
   * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
   */
  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC165, IERC165)
    returns (bool)
  {
    return
      //TODO
      interfaceId == type(IERC721).interfaceId ||
      interfaceId == type(IERC721Metadata).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IERC721-balanceOf}.
   */
  function balanceOf(address owner) public view virtual override returns (uint256) {
    //require(owner != address(0), 'ERC721: address zero is not a valid owner');
    //return _balances[owner];
    //発行されているすべてのtokenIdを検索する必要がある
    uint256 _rental;
    uint256 _lend;
    for (uint256 i = 0; i < _allTokens.length; i++) {
      // レンタル中であれば（この時点では誰が借りているかは不明
      if (_owners[_allTokens[i]].expires >= block.timestamp) {
        // 実行者がどれくらい該当するかを総和してく
        if (_owners[_allTokens[i]].owner == owner) {
          _rental++;
        }
        if (_owners[_allTokens[i]].lender == owner) {
          _lend++;
        }
      }
    }
    return _rental + superOwnerBalanceOf(owner) - _lend; // 自分で保有している分とレンタルしている分を合わせた数量を返す
  }

  // RentaFi Native
  function superOwnerBalanceOf(address superOwner) public view virtual returns (uint256) {
    require(superOwner != address(0), 'ERC721: address zero is not a valid owner');
    return _superOwnerBalances[superOwner];
  }

  /* MODIFIED
   * @dev See {IERC721-ownerOf}.
   */
  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    if (uint256(_owners[tokenId].expires) >= block.timestamp) {
      return _owners[tokenId].owner;
    } else {
      return superOwnerOf(tokenId);
    }
  }

  function setOwner(
    uint256 tokenId,
    address owner,
    uint64 expires
  ) public virtual {
    require(
      _isApprovedOrSuperOwner(msg.sender, tokenId),
      'ERC721: caller is not token superOwner nor approved'
    );
    OwnerInfo storage info = _owners[tokenId];
    info.owner = owner;
    info.expires = expires;
    info.lender = msg.sender;
    emit UpdateOwner(tokenId, owner, msg.sender, expires);
  }

  event UpdateOwner(
    uint256 indexed tokenId,
    address indexed owner,
    address indexed lender,
    uint64 expires
  );

  //RentaFi Native
  function ownerExpires(uint256 tokenId) public view returns (uint256) {
    return _owners[tokenId].expires;
  }

  // RentaFi Native
  function superOwnerOf(uint256 tokenId) public view virtual returns (address) {
    address superOwner = _superOwners[tokenId];
    require(superOwner != address(0), 'ERC721: invalid token ID');
    return superOwner;
  }

  /**
   * @dev See {IERC721Metadata-name}.
   */
  function name() public view virtual override returns (string memory) {
    return _name;
  }

  /**
   * @dev See {IERC721Metadata-symbol}.
   */
  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    _requireMinted(tokenId);

    string memory baseURI = _baseURI();
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : '';
  }

  /**
   * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
   * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
   * by default, can be overridden in child contracts.
   */
  function _baseURI() internal view virtual returns (string memory) {
    return '';
  }

  /**
   * @dev See {IERC721-approve}.
   */
  function approve(address to, uint256 tokenId) public virtual override {
    address superOwner = superOwnerOf(tokenId);
    require(to != superOwner, 'ERC721: approval to current superOwner');

    require(
      _msgSender() == superOwner || isApprovedForAll(superOwner, _msgSender()),
      'ERC721: approve caller is not token superOwner nor approved for all'
    );

    _approve(to, tokenId);
  }

  /**
   * @dev See {IERC721-getApproved}.
   */
  function getApproved(uint256 tokenId) public view virtual override returns (address) {
    _requireMinted(tokenId);

    return _tokenApprovals[tokenId];
  }

  /**
   * @dev See {IERC721-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual override {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC721-isApprovedForAll}.
   */
  function isApprovedForAll(address superOwner, address operator)
    public
    view
    virtual
    override
    returns (bool)
  {
    return _operatorApprovals[superOwner][operator];
  }

  /**
   * @dev See {IERC721-transferFrom}.
   */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    //solhint-disable-next-line max-line-length
    require(
      _isApprovedOrSuperOwner(_msgSender(), tokenId),
      'ERC721: caller is not token superOwner nor approved'
    );

    _transfer(from, to, tokenId);
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, '');
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) public virtual override {
    require(
      _isApprovedOrSuperOwner(_msgSender(), tokenId),
      'ERC721: caller is not token superOwner nor approved'
    );
    _safeTransfer(from, to, tokenId, data);
  }

  /**
   * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
   * are aware of the ERC721 protocol to prevent tokens from being forever locked.
   *
   * `data` is additional data, it has no specified format and it is sent in call to `to`.
   *
   * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
   * implement alternative mechanisms to perform token transfer, such as signature-based.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must exist and be owned by `from`.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function _safeTransfer(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) internal virtual {
    _transfer(from, to, tokenId);
    require(
      _checkOnERC721Received(from, to, tokenId, data),
      'ERC721: transfer to non ERC721Receiver implementer'
    );
  }

  /**
   * @dev Returns whether `tokenId` exists.
   *
   * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
   *
   * Tokens start existing when they are minted (`_mint`),
   * and stop existing when they are burned (`_burn`).
   */
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return _superOwners[tokenId] != address(0);
  }

  /**
   * @dev Returns whether `spender` is allowed to manage `tokenId`.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   */
  function _isApprovedOrSuperOwner(address spender, uint256 tokenId)
    internal
    view
    virtual
    returns (bool)
  {
    address superOwner = superOwnerOf(tokenId);
    return (spender == superOwner ||
      isApprovedForAll(superOwner, spender) ||
      getApproved(tokenId) == spender);
  }

  /**
   * @dev Safely mints `tokenId` and transfers it to `to`.
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function _safeMint(address to, uint256 tokenId) internal virtual {
    _safeMint(to, tokenId, '');
  }

  /**
   * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
   * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
   */
  function _safeMint(
    address to,
    uint256 tokenId,
    bytes memory data
  ) internal virtual {
    _mint(to, tokenId);
    require(
      _checkOnERC721Received(address(0), to, tokenId, data),
      'ERC721: transfer to non ERC721Receiver implementer'
    );
  }

  /**
   * @dev Mints `tokenId` and transfers it to `to`.
   *
   * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - `to` cannot be the zero address.
   *
   * Emits a {Transfer} event.
   */
  function _mint(address to, uint256 tokenId) internal virtual {
    require(to != address(0), 'ERC721: mint to the zero address');
    require(!_exists(tokenId), 'ERC721: token already minted');

    _beforeTokenTransfer(address(0), to, tokenId);

    _superOwnerBalances[to] += 1;
    _superOwners[tokenId] = to;
    _allTokens.push(tokenId);

    emit Transfer(address(0), to, tokenId);

    _afterTokenTransfer(address(0), to, tokenId);
  }

  /**
   * @dev Destroys `tokenId`.
   * The approval is cleared when the token is burned.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   *
   * Emits a {Transfer} event.
   */
  function _burn(uint256 tokenId) internal virtual {
    address superOwner = superOwnerOf(tokenId);

    _beforeTokenTransfer(superOwner, address(0), tokenId);

    // Clear approvals
    _approve(address(0), tokenId);

    _superOwnerBalances[superOwner] -= 1;
    delete _superOwners[tokenId];

    for (uint256 i = 0; i < _allTokens.length; i++) {
      if (_allTokens[i] == tokenId) {
        if (i != _allTokens.length - 1) {
          _allTokens[i] = _allTokens[_allTokens.length - 1];
        }
        _allTokens.pop();
        break;
      }
    }

    emit Transfer(superOwner, address(0), tokenId);

    _afterTokenTransfer(superOwner, address(0), tokenId);
  }

  /**
   * @dev Transfers `tokenId` from `from` to `to`.
   *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `tokenId` token must be owned by `from`.
   *
   * Emits a {Transfer} event.
   */
  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    require(superOwnerOf(tokenId) == from, 'ERC721: transfer from incorrect superOwner');
    require(to != address(0), 'ERC721: transfer to the zero address');

    _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);

    _superOwnerBalances[from] -= 1;
    _superOwnerBalances[to] += 1;
    _superOwners[tokenId] = to;

    emit Transfer(from, to, tokenId);

    _afterTokenTransfer(from, to, tokenId);
  }

  /**
   * @dev Approve `to` to operate on `tokenId`
   *
   * Emits an {Approval} event.
   */
  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(superOwnerOf(tokenId), to, tokenId);
  }

  /**
   * @dev Approve `operator` to operate on all of `owner` tokens
   *
   * Emits an {ApprovalForAll} event.
   */
  function _setApprovalForAll(
    address superOwner,
    address operator,
    bool approved
  ) internal virtual {
    require(superOwner != operator, 'ERC721: approve to caller');
    _operatorApprovals[superOwner][operator] = approved;
    emit ApprovalForAll(superOwner, operator, approved);
  }

  /**
   * @dev Reverts if the `tokenId` has not been minted yet.
   */
  function _requireMinted(uint256 tokenId) internal view virtual {
    require(_exists(tokenId), 'ERC721: invalid token ID');
  }

  /**
   * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
   * The call is not executed if the target address is not a contract.
   *
   * @param from address representing the previous owner of the given token ID
   * @param to target address that will receive the tokens
   * @param tokenId uint256 ID of the token to be transferred
   * @param data bytes optional data to send along with the call
   * @return bool whether the call correctly returned the expected magic value
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) private returns (bool) {
    if (to.isContract()) {
      try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (
        bytes4 retval
      ) {
        return retval == IERC721Receiver.onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert('ERC721: transfer to non ERC721Receiver implementer');
        } else {
          /// @solidity memory-safe-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  /**
   * @dev Hook that is called before any token transfer. This includes minting
   * and burning.
   *
   * Calling conditions:
   *
   * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
   * transferred to `to`.
   * - When `from` is zero, `tokenId` will be minted for `to`.
   * - When `to` is zero, ``from``'s `tokenId` will be burned.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    if (from != to && _owners[tokenId].owner != address(0)) {
      delete _owners[tokenId];
      emit UpdateOwner(tokenId, address(0), address(0), 0);
    }
  }

  /**
   * @dev Hook that is called after any transfer of tokens. This includes
   * minting and burning.
   *
   * Calling conditions:
   *
   * - when `from` and `to` are both non-zero.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {}
}
