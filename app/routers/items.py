from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import Optional
import uuid

router = APIRouter()


class Item(BaseModel):
    id: Optional[str] = None
    name: str
    description: Optional[str] = None
    price: float


# In-memory store for demo purposes
items_db: dict[str, Item] = {}


@router.get("/", response_model=list[Item])
async def list_items():
    return list(items_db.values())


@router.get("/{item_id}", response_model=Item)
async def get_item(item_id: str):
    item = items_db.get(item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@router.post("/", response_model=Item, status_code=status.HTTP_201_CREATED)
async def create_item(item: Item):
    item.id = str(uuid.uuid4())
    items_db[item.id] = item
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(item_id: str):
    if item_id not in items_db:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    del items_db[item_id]
